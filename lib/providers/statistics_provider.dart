import 'dart:async';
import 'package:flutter/material.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';

enum StatsMode { dashboard, filtered }

class StatisticsProvider extends ChangeNotifier {
  final WalletRepository _walletRepository;
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
  bool _isDisposed = false;

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
    required WalletRepository walletRepository,
    required StatsRepository statsRepository,
  })  : _walletRepository = walletRepository,
        _statsRepository = statsRepository {
    // ── Streams-Driven Sync (Phase 1) ──
    // Manual AppEvents listener removed. Data sync is now handled by _summarySubscription
    // and _todayStatsSubscription established in fetchDashboardStats().
  }

  @override
  void dispose() {
    _isDisposed = true;
    _summarySubscription?.cancel();
    _todayStatsSubscription?.cancel();
    _fetchShieldTimer?.cancel();
    super.dispose();
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
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
        _safeNotify();
      }
    }
  }

  Future<void> fetchDashboardStats({bool forceRefresh = false}) async {
    if (_storeId == null) return;

    if (!forceRefresh && _fetchShieldActive) {
      return; // Abort the fetch
    }

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSummary != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      if (_dashboardSummary == null) {
        _dashboardSummary = _cachedSummary;
        _safeNotify();
      }
      return;
    }

    // Cancel old subscriptions
    _summarySubscription?.cancel();
    _todayStatsSubscription?.cancel();

    _isLoading = true;
    _safeNotify();

    _activateFetchShield();

    // 1. Establish Summary Stream
    _summarySubscription = _statsRepository
        .watchStatsSummary(_storeId!)
        .listen((summary) {
      _dashboardSummary = summary;
      _cachedSummary = summary;
      _cacheTimestamp = DateTime.now();
      _isLoading = false;
      _safeNotify();
    }, onError: (e, stack) {
      _setError('حدث خطأ في تيار ملخص الإحصائيات.', e, stack);
    });

    // 2. Establish Today Stats Stream
    _todayStatsSubscription = _statsRepository
        .watchTodayStats(_storeId!)
        .listen((today) {
      _todayStats = today;
      _isLoading = false;
      _safeNotify();
    }, onError: (e, stack) {
      _setError('حدث خطأ في تيار إحصائيات اليوم.', e, stack);
    });
  }

  Future<void> fetchFilteredStats(DateTimeRange dateRange) async {
    _isLoading = true;
    _filteredDateRange = dateRange;
    _mode = StatsMode.filtered;
    _errorMessage = null;
    _filteredStats = null;
    _safeNotify();

    try {
      if (_storeId == null) throw Exception("Store ID not found");

      final List<dynamic> results = await Future.wait([
        _walletRepository.getTotalBalance(_storeId!),
        _walletRepository.getWalletsCount(_storeId!),
      ]);

      final totalBalance = results[0];
      final walletsCount = results[1];

      _filteredStats = {
        'totalBalance': totalBalance,
        'totalWallets': walletsCount,
        'totalTransactions': 0,
        'totalCommission': 0.0,
        'sendCount': 0,
        'totalSentAmount': 0.0,
        'receiveCount': 0,
        'totalReceivedAmount': 0.0,
        'openDebtsCount': 0,
        'totalOpenAmount': 0.0,
        'paidDebtsCount': 0,
        'totalPaidAmount': 0.0,
        'totalDebtsCount': 0,
      };
    } catch (e, stack) {
      _setError("فشل جلب الإحصائيات المفلترة.", e, stack);
      _filteredStats = null;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  void clearFilteredStats() {
    _mode = StatsMode.dashboard;
    _filteredStats = null;
    _filteredDateRange = null;
    _errorMessage = null;
    _safeNotify();
  }

  Future<void> refreshDashboardStats() async {
    if (_storeId != null) {
      await fetchDashboardStats(forceRefresh: true);
    }
  }

  void addTransactionOptimistically(Map<String, dynamic> txData) {
    if (_dashboardSummary == null || _todayStats == null) return;

    final double amount = ((txData['amount'] ?? 0.0) as num).toDouble();
    final double commission = ((txData['commission'] ?? 0.0) as num).toDouble();
    final String? type = txData['type'] as String?;

    // 1. Update Dashboard Summary
    double newTotalReceived = _dashboardSummary!.totalReceivedAmount;
    double newTotalSent = _dashboardSummary!.totalSentAmount;
    int newReceiveCount = _dashboardSummary!.receiveCount;
    int newSendCount = _dashboardSummary!.sendCount;

    if (type == 'credit') {
      newTotalReceived += amount;
      newReceiveCount += 1;
    } else if (type == 'debit') {
      newTotalSent += amount;
      newSendCount += 1;
    }

    _dashboardSummary = _dashboardSummary!.copyWith(
      totalTransactions: _dashboardSummary!.totalTransactions + 1,
      totalTransactionsToday: _dashboardSummary!.totalTransactionsToday + 1,
      totalCommission: _dashboardSummary!.totalCommission + commission,
      totalCommissionToday:
          _dashboardSummary!.totalCommissionToday + commission,
      totalReceivedAmount: newTotalReceived,
      totalSentAmount: newTotalSent,
      receiveCount: newReceiveCount,
      sendCount: newSendCount,
    );

    // 2. Update Today Stats
    _todayStats = _todayStats!.copyWith(
      transactionCount: _todayStats!.transactionCount + 1,
      totalCommission: _todayStats!.totalCommission + commission,
      totalAmount: _todayStats!.totalAmount + amount,
    );

    _safeNotify();
  }

  void _setError(String message, [dynamic e, StackTrace? stack]) {
    _errorMessage = message;
    _isLoading = false;
    if (e != null) {
      AppErrorHandler.handle(e,
          severity: ErrorSeverity.medium,
          operation: 'stats_operation',
          stackTrace: stack);
    }
    _safeNotify();
  }
}
