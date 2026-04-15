import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/providers/app_events.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/models/transaction_model.dart';
import '../data/models/user_model.dart';
import '../core/errors/app_exceptions.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'auth_provider.dart';
import '../core/services/analytics_service.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
enum TransactionStatus { idle, loading, loadingMore, loaded, creating, error }

class TransactionProvider extends ChangeNotifier {
  final TransactionRepository _transactionRepository;

  // State
  String? _currentStoreId;
  UserModel? _currentUser;
  List<TransactionModel> _transactions = [];
  Map<String, TransactionModel> _transactionMap = {};
  List<TransactionModel> _todayTransactions = [];
  Map<String, dynamic> _summary = {};

  // Fetch Shield
  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;
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
  DateTime? _lastOptimisticUpdate;

  StreamSubscription? _dataChangedSubscription;
  bool _isDisposed = false;

  // Constructor
  TransactionProvider({
    TransactionRepository? transactionRepository,
    String? storeId,
  })  : _transactionRepository =
            transactionRepository ?? sl<TransactionRepository>(),
        _currentStoreId = storeId {
    _dataChangedSubscription = appEvents.onTransactionsChanged.listen((_) {
      if (_currentStoreId != null && !isLoading && !isLoadingMore && !_fetchShieldActive) {
        fetchInitialTransactions(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _fetchShieldTimer?.cancel();
    _isDisposed = true;
    _dataChangedSubscription?.cancel();
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
    _updateStatus(TransactionStatus.loading);
    _safeNotify();
    try {
      _selectedTransaction =
          await _transactionRepository.getTransactionById(transactionId);
      _updateStatus(TransactionStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('فشل جلب تفاصيل المعاملة.', e, stack);
    } finally {
      _safeNotify();
    }
  }

  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {
    if (_currentStoreId == null) return;
    if (_fetchShieldActive) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _lastOptimisticUpdate != null &&
        now.difference(_lastOptimisticUpdate!).inSeconds < 10) {
      return;
    }

    if (!forceRefresh &&
        _cachedTransactions != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      _transactions = _cachedTransactions!;
      if (status != TransactionStatus.loaded) {
        _updateStatus(TransactionStatus.loaded);
        _safeNotify();
      }
      return;
    }

    final trace =
        FirebasePerformance.instance.newTrace('fetch_initial_transactions');
    await trace.start();

    _updateStatus(TransactionStatus.loading);
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
      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      _lastDocument = result['lastDoc'];
      _hasMore = _transactions.length == 20;
      _cachedTransactions = _transactions;
      _cacheTimestamp = now;
      _calculateSummary();
      _updateStatus(TransactionStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('حدث خطأ غير متوقع أثناء جلب المعاملات.', e, stack);
    } finally {
      await trace.stop();
      if (_status == TransactionStatus.loading) {
        _updateStatus(TransactionStatus.loaded);
      }
      _safeNotify();
    }
  }

  Future<void> fetchMoreTransactions() async {
    if (isLoading || isLoadingMore || !_hasMore || _currentStoreId == null) {
      return;
    }

    _updateStatus(TransactionStatus.loadingMore);
    _safeNotify();

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
      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      _lastDocument = result['lastDoc'];
      _hasMore = newTransactions.length == 20;
      _calculateSummary();
      _updateStatus(TransactionStatus.loaded);
    } on ServerException catch (e) {
      _setError(e.message);
    } catch (e, stack) {
      _setError('حدث خطأ غير متوقع أثناء جلب المزيد من المعاملات.', e, stack);
    } finally {
      if (_status == TransactionStatus.loadingMore) {
        _updateStatus(TransactionStatus.loaded);
      }
      _safeNotify();
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
    _updateStatus(TransactionStatus.creating);
    _safeNotify();
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
        createdBy: _currentUser?.userId ?? '',
        createdById: _currentUser?.userId,
        createdByName: _currentUser?.fullName,
        creatorRole: _currentUser?.role,
      );

      await _transactionRepository.createTransaction(newTransaction);
      AnalyticsService.logTransactionCreated(transactionType);
      appEvents.fireTransactionsChanged();
      appEvents.fireWalletsChanged();
      return true;
    } on AppException catch (e) {
      _setError(e.message);
      return false;
    } catch (e, stack) {
      _setError('فشل في إنشاء المعاملة.', e, stack);
      return false;
    } finally {
      if (_status == TransactionStatus.creating) {
        _updateStatus(TransactionStatus.idle);
      }
      _safeNotify();
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
    } catch (e, stack) {
      _setError('فشل جلب معاملات هذه الفترة.', e, stack);
      return [];
    }
  }

  // Helper Methods
  void _updateStatus(TransactionStatus status) {
    if (_isDisposed) return;
    _status = status;
  }

  void _setError(String message, [Object? error, StackTrace? stack]) {
    if (_isDisposed) return;
    _errorMessage = message;
    _status = TransactionStatus.error;
    AppErrorHandler.handle(error ?? message,
        severity: ErrorSeverity.medium,
        operation: 'transaction_operation',
        stackTrace: stack);
    // Note: notifyListeners() is now handled by the calling method's finally block
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void clearError() {
    if (_isDisposed) return;
    _errorMessage = null;
    _status = TransactionStatus.idle;
    _safeNotify();
  }

  void insertTransactionLocally(Map<String, dynamic> data) {
    try {
      if (_currentStoreId == null) return;
      if (data['walletId'] == null ||
          data['amount'] == null ||
          data['type'] == null) {
        return;
      }

      final type = data['type'] as String; // 'credit' | 'debit'
      String transactionType = 'receive';
      if (type == 'debit') {
        transactionType = 'send';
      }

      // Parse the new fields passed via Vault + Ping
      final transactionId = data['transactionId'] as String? ?? 
          DateTime.now().millisecondsSinceEpoch.toString();
          
      DateTime parsedDate = DateTime.now();
      if (data['transactionDate'] != null) {
        parsedDate = DateTime.tryParse(data['transactionDate'].toString()) ?? DateTime.now();
      }
      
      final storeId = data['storeId'] as String? ?? _currentStoreId!;

      final newTransaction = TransactionModel(
        transactionId: transactionId,
        storeId: storeId,
        walletId: data['walletId'] as String,
        transactionType: transactionType,
        customerPhone: data['sender'] as String?,
        amount: (data['amount'] as num).toDouble(),
        commission: (data['commission'] as num?)?.toDouble() ?? 0.0,
        transactionDate: Timestamp.fromDate(parsedDate),
        createdAt: Timestamp.now(),
        createdBy: _currentUser?.fullName ?? 'SMS Auto',
        createdById: _currentUser?.userId,
        createdByName: _currentUser?.fullName,
        creatorRole: _currentUser?.role,
        isDeleted: false,
        notes: 'آلي عبر الرسائل القصيرة',
      );

      _transactions.insert(0, newTransaction);
      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      _calculateSummary();
      _lastOptimisticUpdate = DateTime.now();
      _activateFetchShield();
      _safeNotify();
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.low,
          operation: 'transaction_local_insert',
          stackTrace: stack);
    }
  }
}
