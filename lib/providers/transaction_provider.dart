import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/models/transaction_model.dart';
import '../data/models/user_model.dart';
import '../core/errors/app_exceptions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import 'base_provider.dart';
import '../core/services/analytics_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';

enum TransactionStatus { idle, loading, loadingMore, loaded, creating, error }

class TransactionProvider extends BaseProvider {
  final TransactionRepository _transactionRepository;

  // State
  String? _currentStoreId;
  UserModel? _currentUser;
  List<TransactionModel> _transactions = [];
  Map<String, TransactionModel> _transactionMap = {};
  List<TransactionModel> _todayTransactions = [];
  Map<String, dynamic> _summary = {};

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  DateTimeRange _dateRange = DateTimeRange(
      start: DateHelper.getStartOfDay(DateTime.now()),
      end: DateHelper.getEndOfDay(DateTime.now()));

  // Status
  TransactionStatus _status = TransactionStatus.idle;
  String? _errorMessage;

  TransactionModel? _selectedTransaction;

  // Filter
  String? _filterType;

  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;

  // Constructor
  TransactionProvider({
    TransactionRepository? transactionRepository,
    String? storeId,
  })  : _transactionRepository =
            transactionRepository ?? sl<TransactionRepository>(),
        _currentStoreId = storeId;

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
      return DateHelper.isSameDay(tx.transactionDate.toDate(), now);
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
  TransactionStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get currentStoreId => _currentStoreId;
  bool get hasMore => _hasMore;
  String? get filterType => _filterType;
  TransactionModel? get selectedTransaction => _selectedTransaction;
  DateTimeRange get dateRange => _dateRange;

  // Helper Getters
  bool get isLoading => _status == TransactionStatus.loading;
  bool get isLoadingMore => _status == TransactionStatus.loadingMore;
  bool get isCreating => _status == TransactionStatus.creating;
  bool get hasError => _status == TransactionStatus.error;

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

  void setFilterType(String? type) {
    _filterType = type;
    fetchInitialTransactions();
  }

  // Alias for setFilterType to fix analyze error
  void setFilter(String? type) => setFilterType(type);

  void _updateStatus(TransactionStatus status) {
    if (isDisposed) return;
    _status = status;
  }

  @override
  void setError(String errorCode, [dynamic error, StackTrace? stack]) {
    debugPrint('💥 [TX ERROR] $errorCode | Error: $error');
    if (stack != null) debugPrint('🔍 [STACK TRACE]: $stack');
    if (isDisposed) return;
    _errorMessage = errorCode;
    _status = TransactionStatus.error;
    if (error != null) {
      AppErrorHandler.handle(error,
          severity: ErrorSeverity.medium,
          operation: 'transaction_operation',
          stackTrace: stack);
    }
    safeNotify();
  }

  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {
    debugPrint('🚀 [INIT START] TransactionProvider: fetchInitialTransactions(forceRefresh: $forceRefresh)');
    if (_currentStoreId == null) {
      debugPrint('⚠️ [INIT ABORT] TransactionProvider: No currentStoreId');
      return;
    }
    if (!forceRefresh && _fetchShieldActive) {
      debugPrint('🛡️ [INIT SHIELD] TransactionProvider: Fetch shield active, skipping.');
      return;
    }

    _updateStatus(TransactionStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      debugPrint('⏳ [INIT DATA] TransactionProvider: Requesting transactions from repository...');
      final result = await _transactionRepository.getTransactionsByDateRange(
        _currentStoreId!,
        _dateRange.start,
        _dateRange.end,
      );
      debugPrint('✅ [INIT SUCCESS] TransactionProvider: Fetched ${result.items.length} transactions.');

      _transactions = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;

      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      _calculateSummary();
      _updateStatus(TransactionStatus.loaded);
    } catch (e, stack) {
      debugPrint('❌ [INIT FATAL] TransactionProvider Error: $e');
      debugPrint('🔍 [STACK TRACE]: $stack');
      setError('فشل في جلب المعاملات.', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<void> fetchMoreTransactions() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null || _lastDocument == null) {
      return;
    }

    _updateStatus(TransactionStatus.loadingMore);
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
      _calculateSummary();
      _updateStatus(TransactionStatus.loaded);
    } catch (e, stack) {
      setError('فشل في جلب المزيد من المعاملات.', e, stack);
    } finally {
      safeNotify();
    }
  }

  void _calculateSummary() {
    double totalCommission = 0;
    double totalAmount = 0;
    int sendCount = 0;
    int receiveCount = 0;

    for (var tx in _transactions) {
      totalCommission += tx.commission;
      totalAmount += tx.amount;
      if (tx.isSend) sendCount++;
      if (tx.isReceive) receiveCount++;
    }

    _summary = {
      'totalTransactions': _transactions.length,
      'totalCommission': totalCommission,
      'totalAmount': totalAmount,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
    };
  }

  Future<bool> createTransaction({
    required String walletId,
    required String transactionType,
    required double amount,
    required double commission,
    double serviceFee = 0.0,
    String paymentStatus = 'paid',
    String? customerPhone,
    String? customerName,
    String? notes,
  }) async {
    if (_currentStoreId == null) return false;

    _updateStatus(TransactionStatus.creating);
    safeNotify();

    try {
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
        transactionDate: Timestamp.now(),
        createdAt: Timestamp.now(),
        createdBy: _currentUser?.userId ?? 'unknown',
      );

      await _transactionRepository.createTransaction(newTransaction);
      AnalyticsService.logTransactionCreated(transactionType);
      
      _activateFetchShield();
      _updateStatus(TransactionStatus.loaded);
      return true;
    } on AppException catch (e) {
      setError(e.message);
      return false;
    } catch (e, stack) {
      setError('فشل في إنشاء المعاملة.', e, stack);
      return false;
    } finally {
      if (_status == TransactionStatus.creating) {
        _updateStatus(TransactionStatus.loaded);
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
    _transactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    
    _rebuildTransactionMap();
    _recomputeTodayTransactions();
    _calculateSummary();
    _activateFetchShield();
    safeNotify();
  }

  Future<void> selectTransaction(String transactionId) async {
    try {
      final tx = await _transactionRepository.getTransactionById(transactionId);
      _selectedTransaction = tx;
      safeNotify();
    } catch (e, stack) {
      setError('فشل في جلب تفاصيل المعاملة.', e, stack);
    }
  }
}
