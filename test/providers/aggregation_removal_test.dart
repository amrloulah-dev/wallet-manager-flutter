import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';

class MockStatsRepository extends Mock implements StatsRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late StatisticsProvider statisticsProvider;
  late TransactionProvider transactionProvider;
  late MockStatsRepository mockStatsRepository;
  late MockTransactionRepository mockTransactionRepository;

  const storeId = 'test_store';

  setUp(() {
    mockStatsRepository = MockStatsRepository();
    mockTransactionRepository = MockTransactionRepository();

    statisticsProvider =
        StatisticsProvider(statsRepository: mockStatsRepository);
    transactionProvider = TransactionProvider(
      transactionRepository: mockTransactionRepository,
      statsRepository: mockStatsRepository,
      storeId: storeId,
    );
  });

  group('Client-Side Aggregation Removal (TDD - Phase 4)', () {
    test(
        'StatisticsProvider.fetchFilteredStats for today should use StatsSummaryModel from repository',
        () async {
      final summary = StatsSummaryModel(
        totalBalance: 5000.0,
        totalWallets: 5,
        totalTransactionsToday: 10,
        totalCommissionToday: 100.0,
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
      // If we fixed it to read from summary:
      // Current implementation in statistics_provider.dart:154 still uses _todayStats for some fields
      // which we want to move to reading from _dashboardSummary (StatsSummaryModel)
    });

    test('TransactionProvider should not perform manual for-loop aggregations',
        () async {
      final dailyStats = DailyStatsModel(
        date: '2026-05-26',
        transactionCount: 5,
        totalCommission: 50.0,
        totalServiceFee: 10.0,
        totalAmount: 1000.0,
        sendCount: 2,
        receiveCount: 3,
        totalSentAmount: 400.0,
        totalReceivedAmount: 600.0,
      );

      registerFallbackValue(DateTime.now());

      when(() => mockStatsRepository.fetchTodayStats(storeId))
          .thenAnswer((_) async => dailyStats);

      when(() => mockTransactionRepository.getTransactionsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: any(named: 'lastDocument'),
          )).thenAnswer((_) async => PaginatedResult<TransactionModel>(items: [], lastDocument: null));

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
