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
    });
  });
}
