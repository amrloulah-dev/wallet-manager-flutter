import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import '../core/utils/number_parser.dart';
import '../core/enums/transaction_enums.dart';
import 'base_provider.dart';

enum StatsMode { dashboard, filtered }

class StatisticsProvider extends BaseProvider {
  final StatsRepository _statsRepository;

  String? _storeId;

  // State
  StatsMode _mode = StatsMode.dashboard;
  DateTimeRange? _filteredDateRange;
  Map<String, dynamic>? _filteredStats;
  StatsSummaryModel? _dashboardSummary;
  DailyStatsModel? _todayStats;

  bool _isLoading = false;
  String? _errorMessage;

  // Cache
  StatsSummaryModel? _cachedSummary;
  DateTime? _cacheTimestamp;

  Timer? _fetchShieldTimer;
  bool _fetchShieldActive = false;

  void _activateFetchShield() {
    _fetchShieldActive = true;
    _fetchShieldTimer?.cancel();
    _fetchShieldTimer = Timer(const Duration(seconds: 5), () {
      _fetchShieldActive = false;
    });
  }

  // Getters
  StatsMode get mode => _mode;
  DateTimeRange? get filteredDateRange => _filteredDateRange;
  Map<String, dynamic>? get filteredStats => _filteredStats;
  StatsSummaryModel? get dashboardSummary => _dashboardSummary;
  DailyStatsModel? get todayStats => _todayStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  StatisticsProvider({
    required StatsRepository statsRepository,
  }) : _statsRepository = statsRepository {
    // ── Streams-Driven Sync (Phase 1) ──
    // Manual AppEvents listener removed. Data sync is now handled by _summarySubscription
    // and _todayStatsSubscription established in fetchDashboardStats().
  }

  @override
  void dispose() {
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  void setStoreId(String? storeId) {
    if (_storeId != storeId) {
      _storeId = storeId;
      if (storeId != null && storeId.isNotEmpty) {
        fetchDashboardStats();
      } else {
        _dashboardSummary = null;
        _todayStats = null;
        _cachedSummary = null;
        _cacheTimestamp = null;
        _isLoading = false;
        safeNotify();
      }
    }
  }

  Future<void> fetchDashboardStats({bool forceRefresh = false}) async {
    if (kDebugMode) {
      debugPrint(
          '🚀 [INIT START] StatisticsProvider: fetchDashboardStats(forceRefresh: $forceRefresh)');
    }
    if (_storeId == null) {
      if (kDebugMode) {
        debugPrint('⚠️ [INIT ABORT] StatisticsProvider: No storeId');
      }
      return;
    }

    if (!forceRefresh && _fetchShieldActive) {
      if (kDebugMode) {
        debugPrint(
            '🛡️ [INIT SHIELD] StatisticsProvider: Fetch shield active, skipping.');
      }
      return; // Abort the fetch
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSummary != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      if (_dashboardSummary == null) {
        if (kDebugMode) {
          debugPrint(
              '✅ [INIT CACHE] StatisticsProvider: Using cached dashboard summary.');
        }
        _dashboardSummary = _cachedSummary;
        safeNotify();
      }
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    safeNotify();

    _activateFetchShield();

    if (kDebugMode) {
      debugPrint(
          '⏳ [INIT DATA] StatisticsProvider: Fetching stats via Futures...');
    }

    try {
      final summary = await _statsRepository.getStatsSummary(_storeId!);
      _dashboardSummary = summary;
      _cachedSummary = summary;
      _cacheTimestamp = DateTime.now();

      final today = await _statsRepository.fetchTodayStats(_storeId!);
      _todayStats = today;

      _isLoading = false;
      safeNotify();
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
            '❌ [INIT FATAL] StatisticsProvider: Fetching dashboard stats failed: $e');
      }
      setError('stats_error_summary_fetch', e, stack);
    }
  }

  Future<void> fetchFilteredStats(DateTimeRange dateRange) async {
    _isLoading = true;
    _filteredDateRange = dateRange;
    _mode = StatsMode.filtered;
    _errorMessage = null;
    _filteredStats = null;
    safeNotify();

    try {
      if (_storeId == null) throw Exception("Store ID not found");

      // Query daily stats rollup for range
      final aggregated = await _statsRepository.getStatsByDateRange(
          _storeId!, dateRange.start, dateRange.end);

      // Include current total balance and total wallets as point-in-time metrics
      final totalBalance = _dashboardSummary?.totalBalance ?? 0.0;
      final totalWallets = _dashboardSummary?.totalWallets ?? 0;

      final openDebts = NumberParser.toInt(aggregated['openDebtsCount']);
      final paidDebts = NumberParser.toInt(aggregated['paidDebtsCount']);

      _filteredStats = {
        'totalBalance': totalBalance,
        'totalWallets': totalWallets,
        'totalTransactions': NumberParser.toInt(aggregated['transactionCount']),
        'totalCommission': NumberParser.toDouble(aggregated['totalCommission']),
        'sendCount': NumberParser.toInt(aggregated['sendCount']),
        'totalSentAmount': NumberParser.toDouble(aggregated['totalSentAmount']),
        'receiveCount': NumberParser.toInt(aggregated['receiveCount']),
        'totalReceivedAmount':
            NumberParser.toDouble(aggregated['totalReceivedAmount']),
        'openDebtsCount': openDebts,
        'totalOpenAmount': NumberParser.toDouble(aggregated['totalOpenAmount']),
        'paidDebtsCount': paidDebts,
        'totalPaidAmount': NumberParser.toDouble(aggregated['totalPaidAmount']),
        'totalDebtsCount': openDebts + paidDebts,
      };
    } catch (e, stack) {
      setError("stats_error_filtered_fetch", e, stack);
      _filteredStats = null;
    } finally {
      _isLoading = false;
      safeNotify();
    }
  }

  void clearFilteredStats() {
    _mode = StatsMode.dashboard;
    _filteredStats = null;
    _filteredDateRange = null;
    _errorMessage = null;
    safeNotify();
  }

  Future<void> refreshDashboardStats() async {
    if (_storeId != null) {
      await fetchDashboardStats(forceRefresh: true);
    }
  }

  void addTransactionOptimistically(Map<String, dynamic> txData) {
    if (_dashboardSummary == null || _todayStats == null) return;

    final String? type = txData['type'] as String?;
    if (type != 'credit' && type != 'debit') return;

    final summary = _dashboardSummary!;
    final today = _todayStats!;

    final double amount = NumberParser.toDouble(txData['amount']);
    final double commission = NumberParser.toDouble(txData['commission']);

    // 1. Update Dashboard Summary
    double newTotalReceived = summary.totalReceivedAmount;
    double newTotalSent = summary.totalSentAmount;
    int newReceiveCount = summary.receiveCount;
    int newSendCount = summary.sendCount;
    double newTotalBalance = summary.totalBalance;

    if (type == 'credit') {
      newTotalReceived += amount;
      newReceiveCount += 1;
      newTotalBalance += amount;
    } else if (type == 'debit') {
      newTotalSent += amount;
      newSendCount += 1;
      newTotalBalance -= amount;
    }

    _dashboardSummary = summary.copyWith(
      totalTransactions: summary.totalTransactions + 1,
      totalCommission: summary.totalCommission + commission,
      totalReceivedAmount: newTotalReceived,
      totalSentAmount: newTotalSent,
      receiveCount: newReceiveCount,
      sendCount: newSendCount,
      totalBalance: newTotalBalance,
    );

    // 2. Update Today Stats
    int newTodayReceiveCount = today.receiveCount;
    int newTodaySendCount = today.sendCount;
    double newTodayReceivedAmount = today.totalReceivedAmount;
    double newTodaySentAmount = today.totalSentAmount;

    if (type == 'credit') {
      newTodayReceiveCount += 1;
      newTodayReceivedAmount += amount;
    } else if (type == 'debit') {
      newTodaySendCount += 1;
      newTodaySentAmount += amount;
    }

    _todayStats = today.copyWith(
      totalTransactions: today.totalTransactions + 1,
      totalCommission: today.totalCommission + commission,
      receiveCount: newTodayReceiveCount,
      sendCount: newTodaySendCount,
      totalReceivedAmount: newTodayReceivedAmount,
      totalSentAmount: newTodaySentAmount,
    );

    safeNotify();
  }

  void addDebtOptimistically({required double amount}) {
    if (_dashboardSummary == null) return;
    final summary = _dashboardSummary!;
    _dashboardSummary = summary.copyWith(
      openDebtsCount: summary.openDebtsCount + 1,
      totalOpenAmount: summary.totalOpenAmount + amount,
    );
    safeNotify();
  }

  void settleDebtOptimistically({required double amount}) {
    if (_dashboardSummary == null) return;
    final summary = _dashboardSummary!;
    _dashboardSummary = summary.copyWith(
      openDebtsCount:
          summary.openDebtsCount > 0 ? summary.openDebtsCount - 1 : 0,
      totalOpenAmount: summary.totalOpenAmount >= amount
          ? summary.totalOpenAmount - amount
          : 0.0,
      paidDebtsCount: summary.paidDebtsCount + 1,
      totalPaidAmount: summary.totalPaidAmount + amount,
    );
    safeNotify();
  }

  void payPartialDebtOptimistically({required double amount}) {
    if (_dashboardSummary == null) return;
    final summary = _dashboardSummary!;
    _dashboardSummary = summary.copyWith(
      totalOpenAmount: summary.totalOpenAmount >= amount
          ? summary.totalOpenAmount - amount
          : 0.0,
      totalPaidAmount: summary.totalPaidAmount + amount,
    );
    safeNotify();
  }

  void rollbackStats(StatsSummaryModel? oldSummary, DailyStatsModel? oldToday) {
    if (oldSummary == null || oldToday == null) {
      return;
    }
    _dashboardSummary = oldSummary;
    _todayStats = oldToday;
    safeNotify();
  }

  void applyTransactionLocally(double amount, bool isIncome,
      {double commission = 0.0}) {
    if (isDisposed) return;
    addTransactionOptimistically({
      'amount': amount,
      'commission': commission,
      'type': isIncome ? 'credit' : 'debit',
    });
  }

  void updateLocalStats(double amount, dynamic type,
      {double commission = 0.0}) {
    if (isDisposed) return;
    final TransactionType t = type is String
        ? TransactionType.fromString(type)
        : (type is TransactionType ? type : TransactionType.credit);
    final isIncome = t == TransactionType.credit;
    applyTransactionLocally(amount, isIncome, commission: commission);
    notifyListeners();
  }

  @override
  void safeNotify() {
    if (!isDisposed && hasListeners) {
      notifyListeners();
    }
  }

  @override
  void setError(String errorCode,
      [Object? error,
      StackTrace? stack,
      bool showToast = false,
      String operation = 'stats_operation']) {
    if (kDebugMode) {
      if (kDebugMode) debugPrint('💥 [STATS ERROR] $errorCode | Error: $error');
      if (stack != null) {
        if (kDebugMode) debugPrint('🔍 [STACK TRACE]: $stack');
      }
    }

    if (isDisposed) return;
    _errorMessage = errorCode;
    _isLoading = false;

    super.setError(
      errorCode,
      error,
      stack,
      showToast,
      operation,
    );

    safeNotify();
  }

  void clearAndCancel() {
    _storeId = null;
    _fetchShieldTimer?.cancel();
    _dashboardSummary = null;
    _todayStats = null;
    _cachedSummary = null;
    _cacheTimestamp = null;
    _isLoading = false;
    _errorMessage = null;
    _filteredStats = null;
    _filteredDateRange = null;
    safeNotify();
  }
}
