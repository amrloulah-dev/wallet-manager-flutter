import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../data/repositories/debt_repository.dart';
import '../data/models/debt_model.dart';
import '../core/errors/app_exceptions.dart';

enum DebtStatus {
  idle,
  loading,
  loadingMore,
  loaded,
  creating,
  updating,
  error
}

class DebtProvider extends ChangeNotifier {
  final DebtRepository _debtRepository;

  // State
  String? _currentStoreId;
  List<DebtModel> _debts = [];
  Map<String, dynamic> _summary = {};
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  // Status
  DebtStatus _status = DebtStatus.idle;
  String? _errorMessage;

  // Filter
  String _currentFilter = 'all'; // 'all' | 'open' | 'paid'
  String _currentDebtType = 'transaction'; // 'transaction' | 'store_sale'

  // Cache
  List<DebtModel>? _cachedDebts;
  DateTime? _cacheTimestamp;

  StreamSubscription? _dataChangedSubscription;
  bool _isDisposed = false;

  // Constructor
  DebtProvider({
    DebtRepository? debtRepository,
    String? storeId,
  })  : _debtRepository = debtRepository ?? DebtRepository(),
        _currentStoreId = storeId {
    _dataChangedSubscription = appEvents.onDebtsChanged.listen((_) {
      if (_currentStoreId != null && !isLoading && !isLoadingMore) {
        fetchInitialDebts(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dataChangedSubscription?.cancel();
    super.dispose();
  }

  // Getters
  List<DebtModel> get debts => _debts;
  Map<String, dynamic> get summary => _summary;
  DebtStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;
  String get currentDebtType => _currentDebtType;
  String? get currentStoreId => _currentStoreId;
  bool get hasMore => _hasMore;

  // Helper getters
  bool get isLoading => _status == DebtStatus.loading;
  bool get isLoadingMore => _status == DebtStatus.loadingMore;
  bool get isCreating => _status == DebtStatus.creating;
  bool get isUpdating => _status == DebtStatus.updating;
  bool get hasError => _status == DebtStatus.error;

  // Methods

  void setStoreId(String storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      _cachedDebts = null;
      _cacheTimestamp = null;
      fetchInitialDebts();
    }
  }

  void setDebtType(String type) {
    if (_currentDebtType != type) {
      _currentDebtType = type;
      _cachedDebts = null;
      _cacheTimestamp = null;
      // Reset filter if needed or keep it. Keeping it is fine.
      fetchInitialDebts(forceRefresh: true);
    }
  }

  Future<void> fetchInitialDebts({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedDebts != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      _debts = _cachedDebts!;
      if (status != DebtStatus.loaded) {
        _setStatus(DebtStatus.loaded);
      }
      return;
    }

    final trace = FirebasePerformance.instance.newTrace('fetch_initial_debts');
    await trace.start();

    _setStatus(DebtStatus.loading);
    _lastDocument = null;
    _hasMore = true;

    try {
      final result = await _debtRepository.getDebtsByStoreIdPaginated(
        _currentStoreId!,
        status: _currentFilter == 'all' ? null : _currentFilter,
        type: _currentDebtType,
        limit: 20,
      );

      _debts = result['debts'];
      _lastDocument = result['lastDoc'];
      _hasMore = _debts.length == 20;
      _cachedDebts = _debts;
      _cacheTimestamp = now;

      await _fetchSummary();
      _setStatus(DebtStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred while fetching debts.');
    } finally {
      await trace.stop();
    }
  }

  Future<void> fetchMoreDebts() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null)
      return;

    _setStatus(DebtStatus.loadingMore);

    try {
      final result = await _debtRepository.getDebtsByStoreIdPaginated(
        _currentStoreId!,
        status: _currentFilter == 'all' ? null : _currentFilter,
        type: _currentDebtType,
        limit: 20,
        lastDoc: _lastDocument,
      );

      final newDebts = result['debts'];
      _debts.addAll(newDebts);
      _lastDocument = result['lastDoc'];
      _hasMore = newDebts.length == 20;

      _setStatus(DebtStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred while fetching more debts.');
    }
  }

  Future<void> _fetchSummary() async {
    if (_currentStoreId == null) return;
    try {
      final stats = await _debtRepository.fetchDebtStatistics(
        storeId: _currentStoreId!,
        type: _currentDebtType,
      );

      _summary = {
        'openDebtsCount': stats['openCount'],
        'paidDebtsCount': stats['paidCount'],
        'totalDebtsCount':
            (stats['openCount'] as int) + (stats['paidCount'] as int),
        'totalOpenAmount': stats['openTotal'],
        'totalPaidAmount': stats['paidTotal'],
      };
    } catch (e) {
      _summary = {};
    }
  }

  Future<bool> createDebt({
    required String customerName,
    required String customerPhone,
    required String debtType,
    required double amountDue,
    String? notes,
    required String createdBy,
  }) async {
    _setStatus(DebtStatus.creating);
    try {
      if (_currentStoreId == null)
        throw ValidationException('Store ID not found.');
      if (amountDue <= 0) throw ValidationException('Amount must be positive.');

      // This logic for updating an existing debt is complex and should ideally be a transaction.
      // For now, we adapt it to use the new transactional create method.
      final existingDebtByPhone = await _debtRepository.getDebtByCustomerPhone(
          _currentStoreId!, customerPhone);
      if (existingDebtByPhone != null) {
        // --- CORRECTED: Use the new transactional method ---
        return await addPartialDebt(
            existingDebtByPhone.debtId, amountDue, createdBy);
      } else {
        final newDebt = DebtModel(
          debtId: FirebaseFirestore.instance.collection('debts').doc().id,
          storeId: _currentStoreId!,
          customerName: customerName,
          customerPhone: customerPhone,
          debtType: debtType,
          amountDue: amountDue,
          totalAmount: amountDue, // Set totalAmount explicitly
          notes: notes,
          debtDate: Timestamp.now(),
          createdAt: Timestamp.now(),
          createdBy: createdBy,
        );
        await _debtRepository.createDebt(newDebt);
      }

      appEvents.fireDebtsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to create debt.');
      return false;
    }
  }

  Future<bool> addPartialDebt(
      String debtId, double amountToAdd, String userId) async {
    _setStatus(DebtStatus.updating);
    try {
      await _debtRepository.addPartialDebt(debtId, amountToAdd, userId);
      appEvents.fireDebtsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to add to debt.');
      return false;
    }
  }

  Future<bool> updateDebt(String debtId, Map<String, dynamic> data) async {
    _setStatus(DebtStatus.updating);
    try {
      await _debtRepository.updateDebt(debtId, data);
      appEvents.fireDebtsChanged();
      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to update debt.');
      return false;
    }
  }

  Future<bool> payPartialDebt(
      String debtId, double amountToPay, String userId) async {
    _setStatus(DebtStatus.updating);
    try {
      // The provider now just calls the atomic repository method
      await _debtRepository.processPayment(debtId, amountToPay, userId);
      appEvents.fireDebtsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to process payment.');
      return false;
    }
  }

  Future<bool> deleteDebt(String debtId) async {
    _setStatus(DebtStatus.updating);
    try {
      await _debtRepository.deleteDebt(debtId);

      // Remove from local list
      _debts.removeWhere((element) => element.debtId == debtId);

      // Refresh statistics as totals changed
      await _fetchSummary();

      _setStatus(DebtStatus.loaded);
      appEvents.fireStatsRefresh();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to delete debt.');
      return false;
    }
  }

  void setFilter(String filter) {
    if (['all', 'open', 'paid'].contains(filter) && _currentFilter != filter) {
      _currentFilter = filter;
      fetchInitialDebts(forceRefresh: true);
    }
  }

  // Helper Methods
  void _setStatus(DebtStatus status) {
    if (_isDisposed) return;
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = DebtStatus.error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _status = DebtStatus.idle;
    notifyListeners();
  }

  Future<List<DebtModel>> fetchDebtsForDateRange(
      DateTime startDate, DateTime endDate) async {
    if (_currentStoreId == null) return [];
    try {
      return await _debtRepository.getDebtsByDateRange(
          _currentStoreId!, startDate, endDate);
    } catch (e) {
      _setError('Failed to fetch debts for date range.');
      return [];
    }
  }
}
