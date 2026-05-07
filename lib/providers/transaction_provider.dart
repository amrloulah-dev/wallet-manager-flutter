import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/models/transaction_model.dart';
import '../data/models/user_model.dart';
import '../core/errors/app_exceptions.dart';
import '../core/errors/app_error_handler.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import '../core/services/analytics_service.dart';

enum TransactionProviderStatus {
  idle,
  loading,
  loadingMore,
  loaded,
  creating,
  error
}

class TransactionProvider extends BaseProvider {
  final TransactionRepository _transactionRepository;

  // State
  String? _currentStoreId;
  UserModel? _currentUser;
  List<TransactionModel> _transactions = [];
  Map<String, TransactionModel> _transactionMap = {};
  List<TransactionModel> _todayTransactions = [];
  Map<String, dynamic> _summary = {};

  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  late DateTimeRange _dateRange;

  // Status
  TransactionProviderStatus _status = TransactionProviderStatus.idle;
  String? _errorMessage;

  TransactionModel? _selectedTransaction;

  // Filter
  TransactionType? _filterType; // ENUM refactor

  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;

  // Constructor
  TransactionProvider({
    TransactionRepository? transactionRepository,
    String? storeId,
  })  : _transactionRepository =
            transactionRepository ?? sl<TransactionRepository>(),
        _currentStoreId = storeId {
    _initializeDateRange();
  }

  void _initializeDateRange() {
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateHelper.getStartOfDay(now),
      end: DateHelper.getEndOfDay(now),
    );
  }

  @override
  void dispose() {
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  void _rebuildTransactionMap() {
    _transactionMap = {
      for (final tx in _transactions) tx.transactionId: tx,
    };
  }

  void _recomputeTodayTransactions() {
    final now = DateTime.now();
    _todayTransactions = _transactions.where((tx) {
      // Safe access for nullable transactionDate
      return DateHelper.isSameDay(tx.transactionDate ?? now, now);
    }).toList();
  }

  void _activateFetchShield() {
    _fetchShieldActive = true;
    _fetchShieldTimer?.cancel();
    _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
      _fetchShieldActive = false;
    });
  }

  // Getters
  List<TransactionModel> get transactions => _transactions;
  Map<String, TransactionModel> get transactionMap => _transactionMap;
  List<TransactionModel> get todayTransactions => _todayTransactions;
  Map<String, dynamic> get summary => _summary;
  TransactionProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  bool get hasMore => _hasMore;
  TransactionType? get filterType => _filterType;
  TransactionModel? get selectedTransaction => _selectedTransaction;
  DateTimeRange get dateRange => _dateRange;

  // Helper Getters
  bool get isLoading => _status == TransactionProviderStatus.loading;
  bool get isLoadingMore => _status == TransactionProviderStatus.loadingMore;
  bool get isCreating => _status == TransactionProviderStatus.creating;
  bool get hasError => _status == TransactionProviderStatus.error;

  // Methods

  void updateAuthState(AuthProvider auth) {
    if (_currentStoreId != auth.currentStoreId) {
      setStoreId(auth.currentStoreId);
    }
    _currentUser = auth.currentUser;
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      if (storeId != null) {
        fetchInitialTransactions();
      }
    }
  }

  void setDateRange(DateTimeRange range) {
    _dateRange = range;
    fetchInitialTransactions();
  }

  void setFilterType(TransactionType? type) {
    // ENUM refactor
    _filterType = type;
    fetchInitialTransactions();
  }

  void _updateStatus(TransactionProviderStatus status) {
    if (isDisposed) return;
    _status = status;
    // Reset error when starting a new operation
    if (status == TransactionProviderStatus.loading ||
        status == TransactionProviderStatus.creating) {
      _errorMessage = null;
    }
    safeNotify();
  }

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'transaction_operation']) {
    if (kDebugMode) {
      if (kDebugMode) debugPrint('💥 [TX ERROR] $errorCode | Error: $error');
      if (stack != null) {
        if (kDebugMode) debugPrint('🔍 [STACK TRACE]: $stack');
      }
    }

    if (isDisposed) return;
    _errorMessage = errorCode;
    _status = TransactionProviderStatus.error;

    super.setError(
      errorCode,
      error,
      stack,
      showToast,
      operation,
    );

    safeNotify();
  }

  @override
  void safeNotify() {
    if (!isDisposed && hasListeners) {
      notifyListeners();
    }
  }

  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {
    if (kDebugMode)
      debugPrint(
          '🚀 [INIT START] TransactionProvider: fetchInitialTransactions(forceRefresh: $forceRefresh)');
    if (_currentStoreId == null) {
      if (kDebugMode)
        debugPrint('⚠️ [INIT ABORT] TransactionProvider: No currentStoreId');
      return;
    }
    if (!forceRefresh && _fetchShieldActive) {
      if (kDebugMode)
        debugPrint(
            '🛡️ [INIT SHIELD] TransactionProvider: Fetch shield active, skipping.');
      return;
    }

    _updateStatus(TransactionProviderStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      if (kDebugMode)
        debugPrint(
            '⏳ [INIT DATA] TransactionProvider: Requesting transactions from repository...');
      final result = await _transactionRepository.getTransactionsByDateRange(
        _currentStoreId!,
        _dateRange.start,
        _dateRange.end,
        lastDocument: null,
      );
      if (kDebugMode)
        debugPrint(
            '✅ [INIT SUCCESS] TransactionProvider: Fetched ${result.items.length} transactions.');

      _transactions = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;

      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      _updateStatus(TransactionProviderStatus.loaded);
    } catch (e, stack) {
      if (kDebugMode)
        debugPrint('❌ [INIT FATAL] TransactionProvider Error: $e');
      if (kDebugMode) debugPrint('🔍 [STACK TRACE]: $stack');
      setError('transaction_error_fetch_failed', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<void> fetchMoreTransactions() async {
    if (isLoading ||
        isLoadingMore ||
        !_hasMore ||
        _currentStoreId == null ||
        _lastDocument == null) {
      return;
    }

    _updateStatus(TransactionProviderStatus.loadingMore);
    safeNotify();

    try {
      final result = await _transactionRepository.getTransactionsByDateRange(
        _currentStoreId!,
        _dateRange.start,
        _dateRange.end,
        lastDocument: _lastDocument,
      );

      if (result.items.isEmpty) {
        _hasMore = false;
      } else {
        _transactions.addAll(result.items);
        _lastDocument = result.lastDocument;
        _hasMore = result.items.length >= 20;
      }

      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      _updateStatus(TransactionProviderStatus.loaded);
    } catch (e, stack) {
      setError('transaction_error_fetch_more_failed', e, stack);
    } finally {
      safeNotify();
    }
  }

  void _initializeEmptySummary() {
    _summary = {
      'totalTransactions': 0,
      'totalCommission': 0.0,
      'totalAmount': 0.0,
      'sendCount': 0,
      'receiveCount': 0,
    };
  }

  Future<bool> createTransaction({
    required String walletId,
    required TransactionType transactionType, // ENUM refactor
    required double amount,
    required double commission,
    double serviceFee = 0.0,
    PaymentStatus paymentStatus = PaymentStatus.paid, // ENUM refactor
    String? customerPhone,
    String? customerName,
    String? notes,
  }) async {
    if (_currentStoreId == null) return false;

    _status = TransactionProviderStatus.creating;
    _errorMessage = null;
    safeNotify();

    try {
      final now = DateTime.now();
      final newTransaction = TransactionModel(
        transactionId: _transactionRepository.generateId(),
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
        transactionDate: now,
        createdAt: now,
        createdBy: _currentUser?.userId ?? 'unknown',
      );

      await _transactionRepository.createTransaction(newTransaction);
      AnalyticsService.logTransactionCreated(transactionType.name);

      _activateFetchShield();
      _updateStatus(TransactionProviderStatus.loaded);
      return true;
    } on DomainException catch (e) {
      setError(e.message, e);
      if (!AppErrorHandler.isTestMode) ToastUtils.showError(e.message);
      _updateStatus(TransactionProviderStatus.error);
      return false;
    } on ValidationException catch (e) {
      setError(e.message, e);
      if (!AppErrorHandler.isTestMode) ToastUtils.showError(e.message);
      _updateStatus(TransactionProviderStatus.error);
      return false;
    } on AppException catch (e) {
      setError(e.message, e);
      if (!AppErrorHandler.isTestMode) ToastUtils.showError(e.message);
      _updateStatus(TransactionProviderStatus.error);
      return false;
    } catch (e, stack) {
      setError('auth_operation_failed', e, stack);
      if (!AppErrorHandler.isTestMode)
        ToastUtils.showError('auth_operation_failed');
      _updateStatus(TransactionProviderStatus.error);
      return false;
    } finally {
      if (_status == TransactionProviderStatus.creating) {
        _updateStatus(TransactionProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  void insertTransactionLocally(TransactionModel transaction) {
    if (isDisposed) return;

    // Check if it already exists
    if (_transactionMap.containsKey(transaction.transactionId)) return;

    _transactions.add(transaction);
    // Sort by transactionDate descending to maintain consistency with Firestore stream
    // Safe comparison for nullable transactionDate
    final now = DateTime.now();
    _transactions.sort((a, b) =>
        (b.transactionDate ?? now).compareTo(a.transactionDate ?? now));

    _rebuildTransactionMap();
    _recomputeTodayTransactions();
    _activateFetchShield();
    safeNotify();
  }

  Future<void> selectTransaction(String transactionId) async {
    try {
      final tx = await _transactionRepository.getTransactionById(transactionId);
      _selectedTransaction = tx;
      safeNotify();
    } catch (e, stack) {
      setError('transaction_error_details_fetch', e, stack);
    }
  }
}
