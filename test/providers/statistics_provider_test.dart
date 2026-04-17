import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:flutter/material.dart';

class MockWalletRepository extends Mock implements WalletRepository {}
class MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  late StatisticsProvider provider;
  late MockWalletRepository mockWalletRepo;
  late MockStatsRepository mockStatsRepo;

  const storeId = 'test_store';

  setUp(() {
    mockWalletRepo = MockWalletRepository();
    mockStatsRepo = MockStatsRepository();
    
    // Setup default mock behaviors
    when(() => mockStatsRepo.watchStatsSummary(any())).thenAnswer((_) => const Stream.empty());
    when(() => mockStatsRepo.watchTodayStats(any())).thenAnswer((_) => const Stream.empty());

    provider = StatisticsProvider(
      walletRepository: mockWalletRepo,
      statsRepository: mockStatsRepo,
    );
  });

  group('StatisticsProvider Phase 1 Refactor', () {
    test('should be instantiated with only two repositories', () {
      expect(provider, isNotNull);
    });

    test('fetchFilteredStats should return zeros for deleted aggregations', () async {
      when(() => mockWalletRepo.getTotalBalance(storeId)).thenAnswer((_) async => 1000.0);
      when(() => mockWalletRepo.getWalletsCount(storeId)).thenAnswer((_) async => 5);
      
      provider.setStoreId(storeId);
      
      final dateRange = DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      );

      await provider.fetchFilteredStats(dateRange);

      expect(provider.filteredStats, isNotNull);
      expect(provider.filteredStats!['totalBalance'], 1000.0);
      expect(provider.filteredStats!['totalWallets'], 5);
      expect(provider.filteredStats!['totalTransactions'], 0);
      expect(provider.filteredStats!['totalCommission'], 0.0);
    });
  });
}
