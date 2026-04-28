import 'dart:async';
import 'package:flutter/material.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import '../core/utils/number_parser.dart';
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

  StreamSubscription? _summarySubscription;
  StreamSubscription? _todayStatsSubscription;

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

  StatisticsProvider({
    required StatsRepository statsRepository,
  })  : _statsRepository = statsRepository {
    // ── Streams-Driven Sync (Phase 1) ──
    // Manual AppEvents listener removed. Data sync is now handled by _summarySubscription
    // and _todayStatsSubscription established in fetchDashboardStats().
  }

  @override
  void dispose() {
    _summarySubscription?.cancel();
    _todayStatsSubscription?.cancel();
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  void setStoreId(String? storeId) {
    if (_storeId != storeId) {
      _storeId = storeId;
      if (storeId != null) {
        fetchDashboardStats();
      } else {
        _summarySubscription?.cancel();
        _todayStatsSubscription?.cancel();
        _dashboardSummary = null;
        _todayStats = null;
        _cachedSummary = null;
        _cacheTimestamp = null;
        safeNotify();
      }
    }
  }

  Future<void> fetchDashboardStats({bool forceRefresh = false}) async {
    debugPrint('🚀 [INIT START] StatisticsProvider: fetchDashboardStats(forceRefresh: $forceRefresh)');
    if (_storeId == null) {
      debugPrint('⚠️ [INIT ABORT] StatisticsProvider: No storeId');
      return;
    }

    if (!forceRefresh && _fetchShieldActive) {
      debugPrint('🛡️ [INIT SHIELD] StatisticsProvider: Fetch shield active, skipping.');
      return; // Abort the fetch
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSummary != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      if (_dashboardSummary == null) {
        debugPrint('✅ [INIT CACHE] StatisticsProvider: Using cached dashboard summary.');
        _dashboardSummary = _cachedSummary;
        safeNotify();
      }
      return;
    }

    // Cancel old subscriptions
    _summarySubscription?.cancel();
    _todayStatsSubscription?.cancel();

    _isLoading = true;
    safeNotify();

    _activateFetchShield();

    debugPrint('⏳ [INIT DATA] StatisticsProvider: Establishing stats streams...');
    // 1. Establish Summary Stream
    _summarySubscription = _statsRepository
        .watchStatsSummary(_storeId!)
        .listen((summary) {
      debugPrint('✅ [INIT SUCCESS] StatisticsProvider: Received stats summary.');
      _dashboardSummary = summary;
      _cachedSummary = summary;
      _cacheTimestamp = DateTime.now();
      _isLoading = false;
      safeNotify();
    }, onError: (e, stack) {
      debugPrint('❌ [INIT FATAL] StatisticsProvider (SummaryStream): $e');
      setError('حدث خطأ في تيار ملخص الإحصائيات.', e, stack);
    });

    // 2. Establish Today Stats Stream
    _todayStatsSubscription = _statsRepository
        .watchTodayStats(_storeId!)
        .listen((today) {
      debugPrint('✅ [INIT SUCCESS] StatisticsProvider: Received today stats.');
      _todayStats = today;
      _isLoading = false;
      safeNotify();
    }, onError: (e, stack) {
      debugPrint('❌ [INIT FATAL] StatisticsProvider (TodayStatsStream): $e');
      setError('حدث خطأ في تيار إحصائيات اليوم.', e, stack);
    });
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

      // Check if it's today's range
      final isToday = DateHelper.isToday(dateRange.start) && DateHelper.isToday(dateRange.end);

      if (isToday && _todayStats != null && _dashboardSummary != null) {
        _filteredStats = {
          'totalBalance': _dashboardSummary?.totalBalance ?? 0.0,
          'totalWallets': _dashboardSummary?.totalWallets ?? 0,
          'totalTransactions': _todayStats?.transactionCount ?? 0,
          'totalCommission': _todayStats?.totalCommission ?? 0.0,
          'sendCount': 0, // Breakdown not in daily_stats yet
          'totalSentAmount': _todayStats?.totalAmount ?? 0.0, // Assuming total for today
          'receiveCount': 0,
          'totalReceivedAmount': 0.0,
          'openDebtsCount': _dashboardSummary?.openDebtsCount ?? 0,
          'totalOpenAmount': _dashboardSummary?.totalOpenAmount ?? 0.0,
          'paidDebtsCount': _dashboardSummary?.paidDebtsCount ?? 0,
          'totalPaidAmount': _dashboardSummary?.totalPaidAmount ?? 0.0,
          'totalDebtsCount': (_dashboardSummary?.openDebtsCount ?? 0) +
              (_dashboardSummary?.paidDebtsCount ?? 0),
        };
      } else if (_dashboardSummary != null) {
        // Fallback to global summary for other ranges (Phase 3 constraint)
        _filteredStats = _dashboardSummary?.toMap();
      }
    } catch (e, stack) {
      setError("فشل جلب الإحصائيات المفلترة.", e, stack);
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

    final summary = _dashboardSummary!;
    final today = _todayStats!;

    final double amount = NumberParser.toDouble(txData['amount']);
    final double commission = NumberParser.toDouble(txData['commission']);
    final String? type = txData['type'] as String?;

    // 1. Update Dashboard Summary
    double newTotalReceived = summary.totalReceivedAmount;
    double newTotalSent = summary.totalSentAmount;
    int newReceiveCount = summary.receiveCount;
    int newSendCount = summary.sendCount;

    if (type == 'credit') {
      newTotalReceived += amount;
      newReceiveCount += 1;
    } else if (type == 'debit') {
      newTotalSent += amount;
      newSendCount += 1;
    }

    _dashboardSummary = summary.copyWith(
      totalTransactions: summary.totalTransactions + 1,
      totalTransactionsToday: summary.totalTransactionsToday + 1,
      totalCommission: summary.totalCommission + commission,
      totalCommissionToday: summary.totalCommissionToday + commission,
      totalReceivedAmount: newTotalReceived,
      totalSentAmount: newTotalSent,
      receiveCount: newReceiveCount,
      sendCount: newSendCount,
    );

    // 2. Update Today Stats
    _todayStats = today.copyWith(
      transactionCount: today.transactionCount + 1,
      totalCommission: today.totalCommission + commission,
      totalAmount: today.totalAmount + amount,
    );

    safeNotify();
  }

  @override
  void setError(String errorCode, [Object? error, StackTrace? stack, bool showToast = false, String operation = 'stats_operation']) {
    debugPrint('💥 [STATS ERROR] $errorCode | Error: $error');
    if (stack != null) debugPrint('🔍 [STACK TRACE]: $stack');
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
}
