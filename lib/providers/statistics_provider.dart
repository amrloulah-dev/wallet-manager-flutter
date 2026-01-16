import 'dart:async';
import 'package:flutter/material.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/providers/app_events.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';

enum StatsMode { dashboard, filtered }

class StatisticsProvider extends ChangeNotifier {
  final WalletRepository _walletRepository;
  final TransactionRepository _transactionRepository;
  final DebtRepository _debtRepository;
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

  StreamSubscription? _debtsChangedSubscription;
  StreamSubscription? _walletsChangedSubscription;
  StreamSubscription? _transactionsChangedSubscription;
  bool _isDisposed = false;

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
    required TransactionRepository transactionRepository,
    required DebtRepository debtRepository,
    required StatsRepository statsRepository,
  })  : _walletRepository = walletRepository,
        _transactionRepository = transactionRepository,
        _debtRepository = debtRepository,
        _statsRepository = statsRepository {
    _debtsChangedSubscription = appEvents.onDebtsChanged.listen((_) {
      if (_storeId != null) {
        fetchDashboardStats(forceRefresh: true);
      }
    });
    _walletsChangedSubscription = appEvents.onWalletsChanged.listen((_) {
      if (_storeId != null) {
        fetchDashboardStats(forceRefresh: true);
      }
    });
    _transactionsChangedSubscription =
        appEvents.onTransactionsChanged.listen((_) {
      if (_storeId != null) {
        fetchDashboardStats(forceRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debtsChangedSubscription?.cancel();
    _walletsChangedSubscription?.cancel();
    _transactionsChangedSubscription?.cancel();
    super.dispose();
  }

  void setStoreId(String? storeId) {
    if (_storeId != storeId) {
      _storeId = storeId;
      if (storeId != null) {
        fetchDashboardStats();
      } else {
        _dashboardSummary = null;
        _todayStats = null;
        _cachedSummary = null;
        _cacheTimestamp = null;
        notifyListeners();
      }
    }
  }

  Future<void> fetchDashboardStats({bool forceRefresh = false}) async {
    if (_storeId == null) return;

    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedSummary != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!).inMinutes < 2) {
      if (_dashboardSummary == null) {
        _dashboardSummary = _cachedSummary;
        notifyListeners();
      }
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _statsRepository.getStatsSummary(_storeId!),
        _statsRepository.fetchTodayStats(_storeId!),
      ]);

      final summary = results[0] as StatsSummaryModel;
      final daily = results[1] as DailyStatsModel;

      _dashboardSummary = summary;
      _todayStats = daily;

      _cachedSummary = summary;
      _cacheTimestamp = now;
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _dashboardSummary = null;
      _isLoading = false;
      _errorMessage = "Failed to load dashboard stats.";
      notifyListeners();
    }
  }

  Future<void> fetchFilteredStats(DateTimeRange dateRange) async {
    _isLoading = true;
    _filteredDateRange = dateRange;
    _mode = StatsMode.filtered;
    _errorMessage = null;
    _filteredStats = null;
    notifyListeners();

    try {
      if (_storeId == null) throw Exception("Store ID not found");

      final startDate = DateHelper.getStartOfDay(dateRange.start);
      final endDate = DateHelper.getEndOfDay(dateRange.end);

      print('Filtering from $startDate to $endDate');

      final List<dynamic> results = await Future.wait([
        _transactionRepository.getTransactionAggregates(_storeId!,
            startDate: startDate, endDate: endDate),
        _debtRepository.getDebtAggregates(_storeId!,
            startDate: startDate, endDate: endDate),
        _walletRepository.getTotalBalance(_storeId!),
        _walletRepository.getWalletsCount(_storeId!),
      ]);

      final transactionSummary = results[0];
      final debtSummary = results[1];
      final totalBalance = results[2];
      final walletsCount = results[3];

      _filteredStats = {
        'totalBalance': totalBalance,
        'totalWallets': walletsCount,
        ...transactionSummary as Map<String, dynamic>,
        ...debtSummary as Map<String, dynamic>,
      };
      print('Filtered stats: $_filteredStats');
    } catch (e) {
      _errorMessage = "Failed to fetch filtered statistics.";
      _filteredStats = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearFilteredStats() {
    _mode = StatsMode.dashboard;
    _filteredStats = null;
    _filteredDateRange = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> refreshDashboardStats() async {
    if (_storeId != null) {
      await fetchDashboardStats(forceRefresh: true);
    }
  }
}
