import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/models/transaction_model.dart';
import '../data/models/user_model.dart';
import '../data/models/user_permissions.dart'; // Added
import '../core/errors/app_exceptions.dart';
import 'auth_provider.dart';

enum TransactionStatus { idle, loading, loadingMore, loaded, creating, error }

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _transactionRepository;

  // State
  String? _currentStoreId;
  UserModel? _currentUser;
  List<TransactionModel> _transactions = [];
  Map<String, dynamic> _summary = {};
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final DateTimeRange _dateRange = DateTimeRange(
      start: DateHelper.getStartOfDay(DateTime.now()),
      end: DateHelper.getEndOfDay(DateTime.now()));

  // Status
  TransactionStatus _status = TransactionStatus.idle;
  String? _errorMessage;

  TransactionModel? _selectedTransaction;

  // Filter
  String? _filterType;

  // Cache
  List<TransactionModel>? _cachedTransactions;
  DateTime? _cacheTimestamp;

  StreamSubscription? _dataChangedSubscription;
  bool _isDisposed = false;

  // Constructor
  TransactionProvider({
    TransactionRepository? transactionRepository,
    String? storeId,
  })  : _transactionRepository =
            transactionRepository ?? TransactionRepository(),
        _currentStoreId = storeId {
    _dataChangedSubscription = appEvents.onTransactionsChanged.listen((_) {
      if (_currentStoreId != null && !isLoading && !isLoadingMore) {
        fetchInitialTransactions(forceRefresh: true);
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
  List<TransactionModel> get transactions => _transactions;
  Map<String, dynamic> get summary => _summary;
  TransactionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  bool get hasMore => _hasMore;
  String? get filterType => _filterType;
  TransactionModel? get selectedTransaction => _selectedTransaction;

  // Helper Getters
  bool get isLoading => _status == TransactionStatus.loading;
  bool get isLoadingMore => _status == TransactionStatus.loadingMore;
  bool get isCreating => _status == TransactionStatus.creating;
  bool get hasError => _status == TransactionStatus.error;

  // Methods
  void updateAuthState(AuthProvider auth) {
    if (_currentStoreId != auth.currentStoreId ||
        _currentUser != auth.currentUser) {
      _currentStoreId = auth.currentStoreId;
      _currentUser = auth.currentUser;

      // Only refresh if store changed (user change doesn't invalidate transaction list usually)
      if (auth.currentStoreId != _currentStoreId) {
        _cachedTransactions = null;
        _cacheTimestamp = null;
        fetchInitialTransactions();
      } else if (_transactions.isEmpty && _currentStoreId != null) {
        // Initial fetch if we have store but no data
        fetchInitialTransactions();
      }
    }
  }

  void setFilter(String? type) {
    if (_filterType != type) {
      _filterType = type;
      fetchInitialTransactions(forceRefresh: true);
    }
  }

  Future<void> selectTransaction(String transactionId) async {
    _setStatus(TransactionStatus.loading);
    try {
      _selectedTransaction =
          await _transactionRepository.getTransactionById(transactionId);
      _setStatus(TransactionStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Failed to fetch transaction details.');
    }
  }

  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedTransactions != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      _transactions = _cachedTransactions!;
      if (status != TransactionStatus.loaded) {
        _setStatus(TransactionStatus.loaded);
      }
      return;
    }

    final trace =
        FirebasePerformance.instance.newTrace('fetch_initial_transactions');
    await trace.start();

    _setStatus(TransactionStatus.loading);
    _lastDocument = null;
    _hasMore = true;

    try {
      final result =
          await _transactionRepository.getTransactionsByDateRangePaginated(
        _currentStoreId!,
        _dateRange.start,
        _dateRange.end,
        transactionType: _filterType,
        limit: 20,
      );

      _transactions = result['transactions'];
      _lastDocument = result['lastDoc'];
      _hasMore = _transactions.length == 20;
      _cachedTransactions = _transactions;
      _cacheTimestamp = now;
      _calculateSummary();
      _setStatus(TransactionStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('An unexpected error occurred while fetching transactions.');
    } finally {
      await trace.stop();
    }
  }

  Future<void> fetchMoreTransactions() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null) {
      return;
    }

    _setStatus(TransactionStatus.loadingMore);

    try {
      final result =
          await _transactionRepository.getTransactionsByDateRangePaginated(
        _currentStoreId!,
        _dateRange.start,
        _dateRange.end,
        transactionType: _filterType,
        limit: 20,
        lastDoc: _lastDocument,
      );

      final newTransactions = result['transactions'] as List<TransactionModel>;
      _transactions.addAll(newTransactions);
      _lastDocument = result['lastDoc'];
      _hasMore = newTransactions.length == 20;
      _calculateSummary();
      _setStatus(TransactionStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError(
          'An unexpected error occurred while fetching more transactions.');
    }
  }

  void _calculateSummary() {
    int sendCount = 0;
    int receiveCount = 0;
    double totalSendAmount = 0.0;
    double totalReceiveAmount = 0.0;
    double totalCommission = 0.0;

    for (final tx in _transactions) {
      if (tx.isSend) {
        sendCount++;
        totalSendAmount += tx.amount;
      } else {
        receiveCount++;
        totalReceiveAmount += tx.amount;
      }
      totalCommission += tx.commission;
    }

    _summary = {
      'totalTransactions': _transactions.length,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'totalSendAmount': totalSendAmount,
      'totalReceiveAmount': totalReceiveAmount,
      'totalCommission': totalCommission,
    };
  }

  Future<bool> createTransaction({
    required String walletId,
    required String transactionType,
    String? customerPhone,
    String? customerName,
    required double amount,
    required double commission,
    double serviceFee = 0.0,
    String paymentStatus = 'paid',
    String? notes,
  }) async {
    _setStatus(TransactionStatus.creating);
    try {
      // Check Permission
      if (_currentUser == null) throw ValidationException('المستخدم غير موجود');
      if (!_currentUser!.hasPermission((p) => p.createTransaction)) {
        throw PermissionException();
      }

      if (_currentStoreId == null) {
        throw ValidationException('Store ID not found.');
      }
      if (amount <= 0) throw ValidationException('Amount must be positive.');

      final newTransaction = TransactionModel(
        transactionId: _transactionRepository.transactionsCollection.doc().id,
        storeId: _currentStoreId!,
        walletId: walletId,
        transactionType: transactionType,
        customerPhone: customerPhone,
        customerName: customerName,
        amount: amount,
        commission: commission,
        serviceFee: serviceFee,
        paymentStatus: paymentStatus,
        notes: notes,
        transactionDate: Timestamp.now(),
        createdAt: Timestamp.now(),
        createdBy: _currentUser?.userId ?? '',
        createdById: _currentUser?.userId,
        createdByName: _currentUser?.fullName,
        creatorRole: _currentUser?.role,
      );

      await _transactionRepository.createTransaction(newTransaction);
      appEvents.fireTransactionsChanged();
      appEvents.fireWalletsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e) {
      _setError('Failed to create transaction.');
      return false;
    }
  }

  Future<List<TransactionModel>> fetchTransactionsForDateRange(
      DateTime startDate, DateTime endDate) async {
    if (_currentStoreId == null) return [];
    try {
      return await _transactionRepository.getTransactionsByDateRange(
        _currentStoreId!,
        startDate,
        endDate,
      );
    } catch (e) {
      _setError('Failed to fetch transactions for date range.');
      return [];
    }
  }

  // Helper Methods
  void _setStatus(TransactionStatus status) {
    if (_isDisposed) return;
    _status = status;
    notifyListeners();
  }

  void _setError(String message) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = TransactionStatus.error;
    notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    _status = TransactionStatus.idle;
    notifyListeners();
  }
}
