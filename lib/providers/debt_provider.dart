import 'package:firebase_performance/firebase_performance.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../data/repositories/debt_repository.dart';
import '../data/models/debt_model.dart';
import '../core/errors/app_exceptions.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../data/models/user_model.dart';
import '../data/models/user_permissions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../providers/auth_provider.dart';
import '../core/services/analytics_service.dart';

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

  String? _currentStoreId;
  final AuthProvider _authProvider;
  List<DebtModel> _debts = [];
  Map<String, DebtModel> _debtMap = {};
  Map<String, dynamic> _summary = {};
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;

  void _activateFetchShield() {
    _fetchShieldActive = true;
    _fetchShieldTimer?.cancel();
    _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
      _fetchShieldActive = false;
    });
  }

  void _rebuildDebtMap() {
    _debtMap = {for (var debt in _debts) debt.debtId: debt};
  }

  // Status
  DebtStatus _status = DebtStatus.idle;
  String? _errorMessage;

  void _updateStatus(DebtStatus status) {
    if (_isDisposed) return;
    _status = status;
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void _setError(String message, [dynamic e, StackTrace? stack]) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = DebtStatus.error;
    if (e != null) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.medium,
          operation: 'debt_operation',
          stackTrace: stack);
    }
  }

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
    required AuthProvider authProvider,
    DebtRepository? debtRepository,
    String? storeId,
  })  : _authProvider = authProvider,
        _debtRepository = debtRepository ?? sl<DebtRepository>(),
        _currentStoreId = storeId {
    _dataChangedSubscription = appEvents.onDebtsChanged.listen((_) {
      if (_currentStoreId != null &&
          !isLoading &&
          !isLoadingMore &&
          !_fetchShieldActive) {
        fetchInitialDebts(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _dataChangedSubscription?.cancel();
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  // Getters
  List<DebtModel> get debts => _debts;
  Map<String, DebtModel> get debtMap => _debtMap;
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

  void updateAuthState(AuthProvider auth) {
    _currentStoreId = auth.currentStoreId;
  }

  Future<UserModel> _validateUserAndPermission(
      bool Function(UserPermissions) selector) async {
    final user = await _authProvider.ensureUserLoaded();

    if (user == null) {
      throw AuthException(
          'فشلت عملية المصادقة، يرجى التأكد من اتصال الإنترنت أو تسجيل الدخول مجدداً');
    }

    if (user.isOwner) return user;

    if (!user.hasPermission(selector)) {
      throw PermissionException();
    }

    return user;
  }

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
      fetchInitialDebts(forceRefresh: true);
    }
  }

  Future<void> fetchInitialDebts({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;

    final now = DateTime.now();
    if (!forceRefresh && _fetchShieldActive) {
      return;
    }

    if (!forceRefresh &&
        _cachedDebts != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      _debts = _cachedDebts!;
      _rebuildDebtMap();
      if (status != DebtStatus.loaded) {
        _updateStatus(DebtStatus.loaded);
        _safeNotify();
      }
      return;
    }

    final trace = FirebasePerformance.instance.newTrace('fetch_initial_debts');
    await trace.start();

    _updateStatus(DebtStatus.loading);
    _lastDocument = null;
    _hasMore = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final result = await _debtRepository.getDebtsByStoreIdPaginated(
        _currentStoreId!,
        status: _currentFilter == 'all' ? null : _currentFilter,
        type: _currentDebtType,
        limit: 20,
      );

      _debts = result['debts'];
      _rebuildDebtMap();
      _lastDocument = result['lastDoc'];
      _hasMore = _debts.length == 20;
      _cachedDebts = _debts;
      _cacheTimestamp = now;

      await _fetchSummary();
      _activateFetchShield();
      _updateStatus(DebtStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('حدث خطأ غير متوقع أثناء جلب الديون.', e, stack);
    } finally {
      await trace.stop();
      if (_status == DebtStatus.loading) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<void> fetchMoreDebts() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null) {
      return;
    }

    _updateStatus(DebtStatus.loadingMore);
    _safeNotify();

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
      _rebuildDebtMap();
      _lastDocument = result['lastDoc'];
      _hasMore = newDebts.length == 20;

      _updateStatus(DebtStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('حدث خطأ غير متوقع أثناء جلب المزيد من الديون.', e, stack);
    } finally {
      if (_status == DebtStatus.loadingMore) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
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
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'debt_search',
          stackTrace: stack);
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
    _updateStatus(DebtStatus.creating);
    _safeNotify();
    try {
      final user = await _validateUserAndPermission((p) => p.createDebt);

      if (_currentStoreId == null) {
        throw ValidationException('Store ID not found.');
      }
      if (amountDue <= 0) throw ValidationException('Amount must be positive.');

      final existingDebtByPhone = await _debtRepository.getDebtByCustomerPhone(
          _currentStoreId!, customerPhone);
      if (existingDebtByPhone != null) {
        return await addPartialDebt(
            existingDebtByPhone.debtId, amountDue, user.userId);
      } else {
        final newDebt = DebtModel(
          debtId: _debtRepository.generateId(),
          storeId: _currentStoreId!,
          customerName: customerName,
          customerPhone: customerPhone,
          debtType: debtType,
          amountDue: amountDue,
          totalAmount: amountDue,
          notes: notes,
          debtDate: Timestamp.now(),
          createdAt: Timestamp.now(),
          createdBy: user.userId,
        );

        _debts.insert(0, newDebt);
        _rebuildDebtMap();

        try {
          await _debtRepository.createDebt(newDebt);
        } catch (e, stack) {
          _debts.remove(newDebt);
          _rebuildDebtMap();
          AppErrorHandler.handle(e,
              severity: ErrorSeverity.medium,
              operation: 'debt_create',
              stackTrace: stack);
          rethrow;
        }
        AnalyticsService.logDebtAdded();
      }

      // Update Stats if it's an employee
      if (user.isEmployee) {
        await _authProvider.updateEmployeeStats(
          userId: user.userId,
          incrementDebts: 1,
        );
      }

      appEvents.fireDebtsChanged();
      _activateFetchShield();
      _updateStatus(DebtStatus.loaded); // Reset status
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في إنشاء الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.creating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> addPartialDebt(
      String debtId, double amountToAdd, String userId) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.createDebt);

      final index = _debts.indexWhere((d) => d.debtId == debtId);
      final oldDebt = index >= 0 ? _debts[index] : null;

      if (index >= 0) {
        _debts[index] = _debts[index].copyWith(
          amountDue: _debts[index].amountDue + amountToAdd,
          totalAmount: _debts[index].totalAmount + amountToAdd,
        );
        _rebuildDebtMap();
      }

      try {
        await _debtRepository.addPartialDebt(debtId, amountToAdd, userId);
      } catch (e) {
        if (oldDebt != null) {
          _debts[index] = oldDebt;
          _rebuildDebtMap();
        }
        rethrow;
      }

      appEvents.fireDebtsChanged();
      _activateFetchShield();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في إضافة المبلغ إلى الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> updateDebt(String debtId, Map<String, dynamic> data) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      // No specific permission for generic update, assuming createDebt or manageDebt covers it
      // If a specific permission is needed, it should be added here.
      // For now we will replicate the check if feasible or leave it if it was open.
      // User requested "Refactor all Write methods", so I'll add a safe check for createDebt as a baseline
      await _validateUserAndPermission((p) => p.createDebt);

      final index = _debts.indexWhere((d) => d.debtId == debtId);
      final oldDebt = index >= 0 ? _debts[index] : null;

      if (index >= 0) {
        // Since we don't know exactly what changed, we can't fully optimistically apply the map for everything
        // But we can attempt for typical fields
        if (data.containsKey('customerName')) {
          _debts[index] =
              _debts[index].copyWith(customerName: data['customerName']);
        }
        if (data.containsKey('customerPhone')) {
          _debts[index] =
              _debts[index].copyWith(customerPhone: data['customerPhone']);
        }
        if (data.containsKey('notes')) {
          _debts[index] = _debts[index].copyWith(notes: data['notes']);
        }
        _rebuildDebtMap();
      }

      try {
        await _debtRepository.updateDebt(debtId, data);
      } catch (e) {
        if (oldDebt != null) {
          _debts[index] = oldDebt;
          _rebuildDebtMap();
        }
        rethrow;
      }

      appEvents.fireDebtsChanged();
      _activateFetchShield();
      return true;
    } on ServerException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في تحديث الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> payPartialDebt(
      String debtId, double amountToPay, String userId) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.collectDebt);

      final index = _debts.indexWhere((d) => d.debtId == debtId);
      final oldDebt = index >= 0 ? _debts[index] : null;

      if (index >= 0) {
        final newDue = _debts[index].amountDue - amountToPay;
        _debts[index] = _debts[index].copyWith(
          amountDue: newDue < 0 ? 0 : newDue,
          debtStatus: newDue <= 0 ? 'paid' : 'open',
        );
        _rebuildDebtMap();
      }

      try {
        await _debtRepository.processPayment(debtId, amountToPay, userId);
      } catch (e) {
        if (oldDebt != null) {
          _debts[index] = oldDebt;
          _rebuildDebtMap();
        }
        rethrow;
      }

      appEvents.fireDebtsChanged();
      _activateFetchShield();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في معالجة الدفعة.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<bool> deleteDebt(String debtId) async {
    _updateStatus(DebtStatus.updating);
    _safeNotify();
    try {
      await _validateUserAndPermission((p) => p.deleteDebt);

      final index = _debts.indexWhere((element) => element.debtId == debtId);
      final oldDebt = index >= 0 ? _debts[index] : null;

      if (index >= 0) {
        _debts.removeAt(index);
        _rebuildDebtMap();
      }

      try {
        await _debtRepository.deleteDebt(debtId);
      } catch (e) {
        if (oldDebt != null) {
          _debts.insert(index, oldDebt);
          _rebuildDebtMap();
        }
        rethrow;
      }

      // Refresh statistics as totals changed
      await _fetchSummary();

      _activateFetchShield();
      _updateStatus(DebtStatus.loaded);
      appEvents.fireStatsRefresh();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في حذف الدين.', e, stack);
      return false;
    } finally {
      if (_status == DebtStatus.updating) {
        _updateStatus(DebtStatus.loaded);
      }
      _safeNotify();
    }
  }

  void setFilter(String filter) {
    if (['all', 'open', 'paid'].contains(filter) && _currentFilter != filter) {
      _currentFilter = filter;
      fetchInitialDebts(forceRefresh: true);
    }
  }

  void clearError() {
    _errorMessage = null;
    _status = DebtStatus.idle;
    _safeNotify();
  }

  Future<List<DebtModel>> fetchDebtsForDateRange(
      DateTime startDate, DateTime endDate) async {
    if (_currentStoreId == null) return [];
    try {
      return await _debtRepository.getDebtsByDateRange(
          _currentStoreId!, startDate, endDate);
    } catch (e, stack) {
      _setError('فشل جلب ديون هذه الفترة.', e, stack);
      _safeNotify();
      return [];
    }
  }
}

