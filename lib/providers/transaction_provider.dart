import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/services/time_service.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../data/repositories/transaction_repository.dart';
import '../data/repositories/stats_repository.dart';
import '../data/repositories/wallet_repository.dart';
import '../data/models/transaction_model.dart';
import '../data/models/stats_summary_model.dart';
import '../data/models/daily_stats_model.dart';
import '../data/models/user_model.dart';
import '../data/models/user_permissions.dart';
import '../core/errors/app_exceptions.dart';
import 'auth_provider.dart';
import 'wallet_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
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
  final StatsRepository _statsRepository;
  final WalletRepository _walletRepository;

  // State
  String? _currentStoreId;
  UserModel? _currentUser;
  List<TransactionModel> _transactions = [];
  Map<String, TransactionModel> _transactionMap = {};
  List<TransactionModel> _todayTransactions = [];
  final Map<String, dynamic> _summary = {};
  final Set<String> _pendingTxIds = {};

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

  WalletProvider? _walletProvider;

  void updateWalletProvider(WalletProvider walletProvider) {
    _walletProvider = walletProvider;
  }

  // Constructor
  TransactionProvider({
    TransactionRepository? transactionRepository,
    StatsRepository? statsRepository,
    WalletRepository? walletRepository,
    String? storeId,
  })  : _transactionRepository =
            transactionRepository ?? sl<TransactionRepository>(),
        _statsRepository = statsRepository ?? sl<StatsRepository>(),
        _walletRepository = walletRepository ?? sl<WalletRepository>(),
        _currentStoreId = storeId {
    _initializeDateRange();
  }

  void _initializeDateRange() {
    final now = TimeService.now();
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
    final now = TimeService.now();
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

  /// Internal security guard for sensitive mutations.
  /// Validates both existence of user and specific granular permission (for employees).
  Future<UserModel> _validateUserAndPermission(
      bool Function(UserPermissions) permissionCheck) async {
    final user = _currentUser;
    if (user == null || _currentStoreId == null) {
      throw AuthException('auth_error_required');
    }

    // Owners bypass granular permission checks
    if (user.isOwner) return user;

    if (user.permissions == null || !permissionCheck(user.permissions!)) {
      throw PermissionDeniedException();
    }
    return user;
  }

  void setStoreId(String? storeId) {
    if (_currentStoreId != storeId) {
      _currentStoreId = storeId;
      if (storeId != null && storeId.isNotEmpty) {
        fetchInitialTransactions();
      } else {
        _transactions = [];
        _transactionMap = {};
        _status = TransactionProviderStatus.idle;
        safeNotify();
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
      debugPrint('💥 [TX ERROR] $errorCode | Error: $error');
      if (stack != null) {
        debugPrint('🔍 [STACK TRACE]: $stack');
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

  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint(
          '🚀 [INIT START] TransactionProvider: fetchInitialTransactions(forceRefresh: $forceRefresh)');
    }
    if (_currentStoreId == null) {
      if (kDebugMode) {
        debugPrint('⚠️ [INIT ABORT] TransactionProvider: No currentStoreId');
      }
      return;
    }
    if (!forceRefresh && _fetchShieldActive) {
      if (kDebugMode) {
        debugPrint(
            '🛡️ [INIT SHIELD] TransactionProvider: Fetch shield active, skipping.');
      }
      return;
    }

    _updateStatus(TransactionProviderStatus.loading);
    _errorMessage = null;
    safeNotify();

    try {
      if (kDebugMode) {
        debugPrint(
            '⏳ [INIT DATA] TransactionProvider: Requesting transactions from repository...');
      }
      final result = await _transactionRepository.getTransactionsByDateRange(
        _currentStoreId!,
        _dateRange.start,
        _dateRange.end,
        lastDocument: null,
      );
      if (kDebugMode) {
        debugPrint(
            '✅ [INIT SUCCESS] TransactionProvider: Fetched ${result.items.length} transactions.');
      }

      // Smart Merge: match incoming documents by UUID, preserving locally pending modifications/items
      final Map<String, TransactionModel> merged = {};
      final incomingIds = result.items.map((tx) => tx.transactionId).toSet();
      for (final tx in result.items) {
        merged[tx.transactionId] = tx;
      }
      for (final tx in _transactions) {
        if (_pendingTxIds.contains(tx.transactionId)) {
          merged[tx.transactionId] = tx;
        }
      }

      final List<TransactionModel> mergedList = [];
      for (final tx in result.items) {
        if (_pendingTxIds.contains(tx.transactionId)) {
          mergedList.add(merged[tx.transactionId]!);
        } else {
          mergedList.add(tx);
        }
      }
      for (final tx in _transactions) {
        if (_pendingTxIds.contains(tx.transactionId) && !incomingIds.contains(tx.transactionId)) {
          // Prepend newly created pending items
          mergedList.insert(0, tx);
        }
      }

      _transactions = mergedList;
      _lastDocument = result.lastDocument;
      _hasMore = result.items.length >= 20;

      _rebuildTransactionMap();
      _recomputeTodayTransactions();
      await fetchTodaySummary();
      _updateStatus(TransactionProviderStatus.loaded);
    } catch (e, stack) {
      if (e is ServerException && e.code == 'permission-denied') {
        if (kDebugMode) debugPrint('🤫 [SILENT ERROR] TransactionProvider: permission-denied (likely native sign-out)');
        return;
      }
      if (kDebugMode) {
        debugPrint('❌ [INIT FATAL] TransactionProvider Error: $e');
      }
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

  Future<bool> createTransaction({
    required String walletId,
    required TransactionType transactionType,
    required double amount,
    required double commission,
    double serviceFee = 0.0,
    PaymentStatus paymentStatus = PaymentStatus.paid,
    String? customerPhone,
    String? customerName,
    String? notes,
  }) async {
    List<TransactionModel>? oldTransactions;
    Map<String, TransactionModel>? oldTransactionMap;
    Map<String, dynamic>? oldSummary;
    StatisticsProvider? statsProvider;
    StatsSummaryModel? oldStatsSummary;
    DailyStatsModel? oldStatsToday;
    String? pendingTxId;

    try {
      final user = await _validateUserAndPermission((p) => p.createTransaction);

      // Validate wallet is not frozen
      final wallet = await _walletRepository.getWalletById(walletId,
          expectedStoreId: _currentStoreId);
      if (wallet == null) {
        throw ValidationException('wallet_not_found');
      }
      final isWalletFrozen = wallet.isFrozen ||
          (_walletProvider?.isWalletFrozenSync(walletId) ?? false);
      if (isWalletFrozen) {
        throw ValidationException('wallet_is_frozen');
      }

      // Perform client-side limit check
      final isSend = transactionType == TransactionType.debit;
      final isReceive = transactionType == TransactionType.credit;
      final isInstaPay = wallet.walletType == WalletType.instaPay;
      final isTelecom = [
        WalletType.vodafoneCash,
        WalletType.orangeCash,
        WalletType.etisalatCash,
        WalletType.wePay
      ].contains(wallet.walletType);

      if (isInstaPay && amount > 70000) {
        throw ValidationException('wallet_error_instapay_limit');
      }
      if (isTelecom && amount > 60000) {
        throw ValidationException('wallet_error_telecom_limit');
      }

      if (isSend) {
        final totalDeduction = amount + serviceFee;
        if ((wallet.balance + 0.01) < totalDeduction) {
          throw ValidationException('wallet_error_insufficient_balance');
        }

        if (wallet.sendLimits.dailyUsed + amount > wallet.getLimits().dailyLimit) {
          throw ValidationException('wallet_error_daily_send_limit');
        }
        if (wallet.sendLimits.monthlyUsed + amount > wallet.getLimits().monthlyLimit) {
          throw ValidationException('wallet_error_monthly_send_limit');
        }
      } else if (isReceive) {
        if (wallet.receiveLimits.dailyUsed + amount > wallet.getReceiveLimits().dailyLimit) {
          throw ValidationException('wallet_error_daily_receive_limit');
        }
        if (wallet.receiveLimits.monthlyUsed + amount > wallet.getReceiveLimits().monthlyLimit) {
          throw ValidationException('wallet_error_monthly_receive_limit');
        }
      }

      _status = TransactionProviderStatus.creating;
      _errorMessage = null;
      safeNotify();

      // Capture snapshots (Isolated copy)
      oldTransactions = _transactions.toList();
      oldTransactionMap = Map<String, TransactionModel>.from(_transactionMap);
      oldSummary = Map<String, dynamic>.from(_summary);

      statsProvider = sl.isRegistered<StatisticsProvider>() ? sl<StatisticsProvider>() : null;
      if (statsProvider != null) {
        oldStatsSummary = statsProvider.dashboardSummary;
        oldStatsToday = statsProvider.todayStats;
      }

      final now = TimeService.now();
      final newTransactionId = const Uuid().v4();
      pendingTxId = newTransactionId;
      _pendingTxIds.add(pendingTxId);
      final newTransaction = TransactionModel(
        transactionId: newTransactionId,
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
        createdBy: user.userId,
      );

      // Optimistic mutation: insert locally first
      _transactions.insert(0, newTransaction);
      _rebuildTransactionMap();
      _recomputeTodayTransactions();

      final double localDeduction = amount + serviceFee;
      final bool isSendDeduction = transactionType == TransactionType.debit;
      _walletProvider?.applyLocalDeduction(walletId, localDeduction, isSendDeduction);

      _updateSummaryMapOptimistically(newTransaction);

      if (statsProvider != null) {
        statsProvider.addTransactionOptimistically({
          'amount': amount,
          'commission': commission,
          'type': transactionType.name,
        });
      }

      safeNotify();

      await _transactionRepository.createTransaction(newTransaction);
      AnalyticsService.logTransactionCreated(transactionType.name);

      _activateFetchShield();
      _updateStatus(TransactionProviderStatus.loaded);
      _walletProvider?.clearPendingWallet(walletId);
      return true;
    } on DomainException catch (e, stack) {
      _rollbackLocalTx(oldTransactions, oldTransactionMap, oldSummary, statsProvider, oldStatsSummary, oldStatsToday, walletId, amount, serviceFee, transactionType);
      setError(e.message, e, stack);
      return false;
    } on ValidationException catch (e, stack) {
      _rollbackLocalTx(oldTransactions, oldTransactionMap, oldSummary, statsProvider, oldStatsSummary, oldStatsToday, walletId, amount, serviceFee, transactionType);
      setError(e.message, e, stack);
      return false;
    } on AppException catch (e, stack) {
      _rollbackLocalTx(oldTransactions, oldTransactionMap, oldSummary, statsProvider, oldStatsSummary, oldStatsToday, walletId, amount, serviceFee, transactionType);
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      _rollbackLocalTx(oldTransactions, oldTransactionMap, oldSummary, statsProvider, oldStatsSummary, oldStatsToday, walletId, amount, serviceFee, transactionType);
      setError('transaction_error_create_failed', e, stack);
      return false;
    } finally {
      if (pendingTxId != null) {
        _pendingTxIds.remove(pendingTxId);
      }
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
    final now = TimeService.now();
    _transactions.sort((a, b) =>
        (b.transactionDate ?? now).compareTo(a.transactionDate ?? now));

    _rebuildTransactionMap();
    _recomputeTodayTransactions();
    _activateFetchShield();
    fetchTodaySummary();
    safeNotify();
  }

  Future<void> fetchTodaySummary() async {
    if (_currentStoreId == null) return;
    try {
      final stats = await _statsRepository.fetchTodayStats(_currentStoreId!);
      if (isDisposed) return;
      _summary['totalTransactions'] = stats.transactionCount;
      _summary['sendCount'] = stats.sendCount;
      _summary['receiveCount'] = stats.receiveCount;
      _summary['totalSendAmount'] = stats.totalSentAmount;
      _summary['totalReceiveAmount'] = stats.totalReceivedAmount;
      _summary['totalCommission'] = stats.totalCommission;
      safeNotify();
    } catch (e, stack) {
      setError('transaction_error_summary_fetch_failed', e, stack);
    }
  }

  Future<void> selectTransaction(String transactionId) async {
    _selectedTransaction = null;
    _errorMessage = null;
    safeNotify();

    try {
      final tx = await _transactionRepository.getTransactionById(transactionId,
          expectedStoreId: _currentStoreId);
      _selectedTransaction = tx;
      _updateStatus(TransactionProviderStatus.loaded);
    } catch (e, stack) {
      setError('transaction_error_details_fetch', e, stack);
    } finally {
      safeNotify();
    }
  }

  Future<bool> updateTransaction(
      String transactionId, Map<String, dynamic> data) async {
    try {
      await _validateUserAndPermission((p) => p.editTransaction);

      // We need to fetch the transaction first to get the walletId to validate if it's frozen.
      final currentTx = await _transactionRepository.getTransactionById(
          transactionId,
          expectedStoreId: _currentStoreId);
      
      if (currentTx == null) {
        throw ValidationException('transaction_not_found');
      }
          
      // Ensure the wallet is not frozen. We use the updated walletId if provided, otherwise the current one.
      final targetWalletId = data['walletId'] as String? ?? currentTx.walletId;
      final wallet = await _walletRepository.getWalletById(targetWalletId,
          expectedStoreId: _currentStoreId);
          
      if (wallet == null) {
        throw ValidationException('wallet_not_found');
      }
      final isWalletFrozen = wallet.isFrozen ||
          (_walletProvider?.isWalletFrozenSync(targetWalletId) ?? false);
      if (isWalletFrozen) {
        throw ValidationException('wallet_is_frozen');
      }

      _updateStatus(TransactionProviderStatus
          .creating); // Using creating for mutating state
      _errorMessage = null;
      safeNotify();

      await _transactionRepository.updateTransaction(transactionId, data);

      await fetchInitialTransactions(forceRefresh: true);
      return true;
    } on DomainException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } on ValidationException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } on AppException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      setError('transaction_error_update_failed', e, stack);
      return false;
    } finally {
      if (_status == TransactionProviderStatus.creating) {
        _updateStatus(TransactionProviderStatus.loaded);
      }
      safeNotify();
    }
  }

  void _updateSummaryMapOptimistically(TransactionModel tx) {
    _summary['totalTransactions'] = (_summary['totalTransactions'] as int? ?? 0) + 1;
    _summary['totalCommission'] = (_summary['totalCommission'] as double? ?? 0.0) + tx.commission;

    if (tx.transactionType == TransactionType.debit) {
      _summary['sendCount'] = (_summary['sendCount'] as int? ?? 0) + 1;
      _summary['totalSendAmount'] = (_summary['totalSendAmount'] as double? ?? 0.0) + tx.amount;
    } else if (tx.transactionType == TransactionType.credit) {
      _summary['receiveCount'] = (_summary['receiveCount'] as int? ?? 0) + 1;
      _summary['totalReceiveAmount'] = (_summary['totalReceiveAmount'] as double? ?? 0.0) + tx.amount;
    }
  }

  void _rollbackLocalTx(
    List<TransactionModel>? oldTransactions,
    Map<String, TransactionModel>? oldTransactionMap,
    Map<String, dynamic>? oldSummary,
    StatisticsProvider? statsProvider,
    StatsSummaryModel? oldStatsSummary,
    DailyStatsModel? oldStatsToday,
    String walletId,
    double amount,
    double serviceFee,
    TransactionType transactionType,
  ) {
    if (oldTransactions != null) _transactions = oldTransactions;
    if (oldTransactionMap != null) _transactionMap = oldTransactionMap;
    if (oldSummary != null) {
      _summary.clear();
      _summary.addAll(oldSummary);
    }
    if (_walletProvider != null) {
      final double localDeduction = amount + serviceFee;
      final bool isSendDeduction = transactionType == TransactionType.debit;
      try {
        _walletProvider!.applyLocalDeduction(walletId, localDeduction, !isSendDeduction);
        _walletProvider!.clearPendingWallet(walletId);
      } catch (_) {}
    }
    if (statsProvider != null) {
      statsProvider.rollbackStats(oldStatsSummary, oldStatsToday);
    }
    _recomputeTodayTransactions();
    safeNotify();
  }

  Future<bool> deleteTransaction(String transactionId) async {
    try {
      // Completely disable deletion according to strict financial integrity business logic
      throw PermissionDeniedException();
    } on AppException catch (e, stack) {
      setError(e.message, e, stack);
      return false;
    } catch (e, stack) {
      setError('transaction_error_delete_failed', e, stack);
      return false;
    }
  }

  void clearAndCancel() {
    _currentStoreId = null;
    _fetchShieldTimer?.cancel();
    _fetchShieldActive = false;
    _transactions = [];
    _transactionMap = {};
    _todayTransactions = [];
    _summary.clear();
    _hasMore = true;
    _lastDocument = null;
    _selectedTransaction = null;
    _status = TransactionProviderStatus.idle;
    _errorMessage = null;
    safeNotify();
  }
}
