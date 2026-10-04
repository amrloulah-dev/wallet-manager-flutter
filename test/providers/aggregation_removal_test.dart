import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:flutter/material.dart';

class MockStatsRepository extends Mock implements StatsRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  late StatisticsProvider statisticsProvider;
  late TransactionProvider transactionProvider;
  late MockStatsRepository mockStatsRepository;
  late MockTransactionRepository mockTransactionRepository;
  late MockWalletRepository mockWalletRepository;

  const storeId = 'test_store';

  setUp(() async {
    await sl.reset();
    AppErrorHandler.isTestMode = true;

    mockStatsRepository = MockStatsRepository();
    mockTransactionRepository = MockTransactionRepository();
    mockWalletRepository = MockWalletRepository();

    final defaultSummary = StatsSummaryModel(
      totalBalance: 5000.0,
      totalWallets: 5,
      totalSentAmount: 2000.0,
      totalReceivedAmount: 3000.0,
      sendCount: 4,
      receiveCount: 6,
    );

    final defaultTodayStats = DailyStatsModel(
      date: '2026-05-26',
      totalTransactions: 5,
      totalCommission: 50.0,
      sendCount: 2,
      receiveCount: 3,
      totalSentAmount: 400.0,
      totalReceivedAmount: 600.0,
    );

    when(() => mockStatsRepository.getStatsSummary(any()))
        .thenAnswer((_) async => defaultSummary);
    when(() => mockStatsRepository.fetchTodayStats(any()))
        .thenAnswer((_) async => defaultTodayStats);

    statisticsProvider =
        StatisticsProvider(statsRepository: mockStatsRepository);
    transactionProvider = TransactionProvider(
      transactionRepository: mockTransactionRepository,
      statsRepository: mockStatsRepository,
      walletRepository: mockWalletRepository,
      storeId: storeId,
    );
  });

  group('Client-Side Aggregation Removal (TDD - Phase 4)', () {
    test(
        'StatisticsProvider.fetchFilteredStats for today should use getStatsByDateRange from repository',
        () async {
      final summary = StatsSummaryModel(
        totalBalance: 5000.0,
        totalWallets: 5,
        totalSentAmount: 2000.0,
        totalReceivedAmount: 3000.0,
        sendCount: 4,
        receiveCount: 6,
      );

      // We need to mock the streams used by fetchDashboardStats because StatisticsProvider listens to them
      when(() => mockStatsRepository.watchStatsSummary(storeId))
          .thenAnswer((_) => Stream.fromIterable([summary]));
      when(() => mockStatsRepository.watchTodayStats(storeId))
          .thenAnswer((_) => Stream.empty());
      when(() => mockStatsRepository.getStatsSummary(any()))
          .thenAnswer((_) async => summary);
      when(() => mockStatsRepository.getStatsByDateRange(storeId, any(), any()))
          .thenAnswer((_) async => {
                'transactionCount': 10,
                'totalCommission': 100.0,
                'sendCount': 4,
                'receiveCount': 6,
                'totalSentAmount': 2000.0,
                'totalReceivedAmount': 3000.0,
                'openDebtsCount': 2,
                'paidDebtsCount': 3,
                'totalOpenAmount': 500.0,
                'totalPaidAmount': 600.0,
              });

      statisticsProvider.setStoreId(storeId);

      // Wait for stream emission
      await Future.delayed(Duration.zero);

      final today = DateTime.now();
      final range = DateTimeRange(start: today, end: today);

      await statisticsProvider.fetchFilteredStats(range);

      final stats = statisticsProvider.filteredStats!;
      expect(stats['totalBalance'], 5000.0);
      expect(stats['totalTransactions'], 10);
      expect(stats['totalCommission'], 100.0);
    });

    test('TransactionProvider should not perform manual for-loop aggregations',
        () async {
      final todayStats = DailyStatsModel(
        date: DateHelper.getCurrentDateString(),
        totalTransactions: 5,
        sendCount: 2,
        receiveCount: 3,
        totalSentAmount: 400.0,
        totalReceivedAmount: 600.0,
        totalCommission: 50.0,
      );

      registerFallbackValue(DateTime.now());

      when(() => mockStatsRepository.fetchTodayStats(storeId))
          .thenAnswer((_) async => todayStats);

      when(() => mockTransactionRepository.getTransactionsByDateRange(
                any(),
                any(),
                any(),
                lastDocument: any(named: 'lastDocument'),
              ))
          .thenAnswer((_) async =>
              PaginatedResult<TransactionModel>(items: [], lastDocument: null));

      // Act
      await transactionProvider.fetchInitialTransactions();

      // Assert
      expect(transactionProvider.summary['totalTransactions'], 5);
      expect(transactionProvider.summary['sendCount'], 2);
      expect(transactionProvider.summary['receiveCount'], 3);
      expect(transactionProvider.summary['totalSendAmount'], 400.0);
      expect(transactionProvider.summary['totalReceiveAmount'], 600.0);
      expect(transactionProvider.summary['totalCommission'], 50.0);

      verify(() => mockStatsRepository.fetchTodayStats(storeId)).called(1);
    });
  });
}
