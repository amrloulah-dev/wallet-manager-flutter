import 'dart:async';
import 'package:flutter/foundation.dart';
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
    if (kDebugMode) debugPrint('🚀 [INIT START] StatisticsProvider: fetchDashboardStats(forceRefresh: $forceRefresh)');
    if (_storeId == null) {
      if (kDebugMode) debugPrint('⚠️ [INIT ABORT] StatisticsProvider: No storeId');
      return;
    }

    if (!forceRefresh && _fetchShieldActive) {
      if (kDebugMode) debugPrint('🛡️ [INIT SHIELD] StatisticsProvider: Fetch shield active, skipping.');
      return; // Abort the fetch
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSummary != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      if (_dashboardSummary == null) {
        if (kDebugMode) debugPrint('✅ [INIT CACHE] StatisticsProvider: Using cached dashboard summary.');
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

    if (kDebugMode) debugPrint('⏳ [INIT DATA] StatisticsProvider: Establishing stats streams...');
    
    // Phase 4: Ensure stats are initialized before watching
    try {
      await _statsRepository.getStatsSummary(_storeId!);
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [INIT WARNING] StatisticsProvider: Initialization failed: $e');
    }

    // 1. Establish Summary Stream
    _summarySubscription = _statsRepository
        .watchStatsSummary(_storeId!)
        .listen((summary) {
      if (kDebugMode) debugPrint('✅ [INIT SUCCESS] StatisticsProvider: Received stats summary.');
      _dashboardSummary = summary;
      _cachedSummary = summary;
      _cacheTimestamp = DateTime.now();
      _isLoading = false;
      safeNotify();
    }, onError: (e, stack) {
      if (kDebugMode) debugPrint('❌ [INIT FATAL] StatisticsProvider (SummaryStream): $e');
      setError('حدث خطأ في تيار ملخص الإحصائيات.', e, stack);
    });

    // 2. Establish Today Stats Stream
    _todayStatsSubscription = _statsRepository
        .watchTodayStats(_storeId!)
        .listen((today) {
      if (kDebugMode) debugPrint('✅ [INIT SUCCESS] StatisticsProvider: Received today stats.');
      _todayStats = today;
      _isLoading = false;
      safeNotify();
    }, onError: (e, stack) {
      if (kDebugMode) debugPrint('❌ [INIT FATAL] StatisticsProvider (TodayStatsStream): $e');
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

      if (isToday && _dashboardSummary != null) {
        final s = _dashboardSummary!;
        _filteredStats = {
          'totalBalance': s.totalBalance,
          'totalWallets': s.totalWallets,
          'totalTransactions': s.totalTransactionsToday,
          'totalCommission': s.totalCommissionToday,
          'sendCount': s.sendCount, 
          'totalSentAmount': s.totalSentAmount,
          'receiveCount': s.receiveCount,
          'totalReceivedAmount': s.totalReceivedAmount,
          'openDebtsCount': s.openDebtsCount,
          'totalOpenAmount': s.totalOpenAmount,
          'paidDebtsCount': s.paidDebtsCount,
          'totalPaidAmount': s.totalPaidAmount,
          'totalDebtsCount': s.openDebtsCount + s.paidDebtsCount,
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
  void safeNotify() {
    if (!isDisposed && hasListeners) {
      notifyListeners();
    }
  }

  @override
  void setError(String errorCode, [Object? error, StackTrace? stack, bool showToast = false, String operation = 'stats_operation']) {
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
}
