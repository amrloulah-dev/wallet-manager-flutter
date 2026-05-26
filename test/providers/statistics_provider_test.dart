import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:flutter/material.dart';

class MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  late StatisticsProvider provider;
  late MockStatsRepository mockStatsRepo;

  const storeId = 'test_store';

  setUp(() {
    mockStatsRepo = MockStatsRepository();

    // Setup default mock behaviors
    final summary = StatsSummaryModel.empty().copyWith(
      totalBalance: 1000.0,
      totalWallets: 5,
    );

    when(() => mockStatsRepo.watchStatsSummary(storeId))
        .thenAnswer((_) => Stream.value(summary));
    when(() => mockStatsRepo.watchTodayStats(storeId))
        .thenAnswer((_) => const Stream.empty());
    when(() => mockStatsRepo.getStatsSummary(any()))
        .thenAnswer((_) async => summary);
    when(() => mockStatsRepo.getStatsByDateRange(any(), any(), any()))
        .thenAnswer((_) async => {
              'transactionCount': 10,
              'sendCount': 4,
              'receiveCount': 6,
              'totalSentAmount': 2000.0,
              'totalReceivedAmount': 3000.0,
              'totalCommission': 100.0,
              'openDebtsCount': 2,
              'paidDebtsCount': 3,
              'totalOpenAmount': 500.0,
              'totalPaidAmount': 600.0,
            });

    provider = StatisticsProvider(
      statsRepository: mockStatsRepo,
    );
  });

  group('StatisticsProvider Phase 3 Refactor', () {
    test('should be instantiated with stats repository', () {
      expect(provider, isNotNull);
    });

    test('fetchFilteredStats should use pre-aggregated summary data', () async {
      provider.setStoreId(storeId);

      // Wait for the stream to emit and update the provider state
      await Future.delayed(Duration.zero);

      final dateRange = DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      );

      await provider.fetchFilteredStats(dateRange);

      expect(provider.filteredStats, isNotNull);
      expect(provider.filteredStats!['totalBalance'], 1000.0);
      expect(provider.filteredStats!['totalWallets'], 5);
      expect(provider.filteredStats!['totalTransactions'], 10);
      expect(provider.filteredStats!['sendCount'], 4);
      expect(provider.filteredStats!['receiveCount'], 6);
      expect(provider.filteredStats!['totalSentAmount'], 2000.0);
      expect(provider.filteredStats!['totalReceivedAmount'], 3000.0);
      expect(provider.filteredStats!['totalCommission'], 100.0);
    });
  });
}
