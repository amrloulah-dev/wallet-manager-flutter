import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
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
    when(() => mockStatsRepo.fetchTodayStats(any()))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-06-05'));
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

      // Wait for the stream/future to emit and update the provider state
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

    test('should fetch dashboard stats using Futures instead of Streams',
        () async {
      final summary = StatsSummaryModel.empty().copyWith(
        totalBalance: 1500.0,
        totalWallets: 3,
      );
      final todayStats = DailyStatsModel.empty('2026-06-05').copyWith(
        totalTransactions: 5,
        totalCommission: 50.0,
      );

      // Reset mock behaviors to verify exact calls
      reset(mockStatsRepo);
      when(() => mockStatsRepo.getStatsSummary(storeId))
          .thenAnswer((_) async => summary);
      when(() => mockStatsRepo.fetchTodayStats(storeId))
          .thenAnswer((_) async => todayStats);

      provider.setStoreId(storeId);
      // Wait for async operations to complete
      await Future.delayed(Duration.zero);

      expect(provider.dashboardSummary, equals(summary));
      expect(provider.todayStats, equals(todayStats));

      verify(() => mockStatsRepo.getStatsSummary(storeId)).called(1);
      verify(() => mockStatsRepo.fetchTodayStats(storeId)).called(1);
      verifyNever(() => mockStatsRepo.watchStatsSummary(any()));
      verifyNever(() => mockStatsRepo.watchTodayStats(any()));
    });

    test(
        'addTransactionOptimistically with credit or debit type should increment counters',
        () {
      final summaryBefore = StatsSummaryModel.empty().copyWith(
        totalTransactions: 10,
        totalCommission: 50.0,
        totalReceivedAmount: 1000.0,
        receiveCount: 3,
        totalBalance: 500.0,
      );
      final todayBefore = DailyStatsModel.empty('2026-06-05').copyWith(
        totalTransactions: 5,
        totalCommission: 10.0,
        receiveCount: 2,
        totalReceivedAmount: 800.0,
      );

      provider.rollbackStats(summaryBefore, todayBefore);

      provider.addTransactionOptimistically({
        'amount': 200.0,
        'commission': 5.0,
        'type': 'credit',
      });

      expect(provider.dashboardSummary!.totalTransactions, 11);
      expect(provider.dashboardSummary!.totalCommission, 55.0);
      expect(provider.dashboardSummary!.totalReceivedAmount, 1200.0);
      expect(provider.dashboardSummary!.receiveCount, 4);
      expect(provider.dashboardSummary!.totalBalance, 700.0);

      expect(provider.todayStats!.totalTransactions, 6);
      expect(provider.todayStats!.totalCommission, 15.0);
      expect(provider.todayStats!.receiveCount, 3);
      expect(provider.todayStats!.totalReceivedAmount, 1000.0);
    });

    test(
        'addTransactionOptimistically with deposit type should NOT increment transaction counts, sent, or received counters',
        () {
      final summaryBefore = StatsSummaryModel.empty().copyWith(
        totalTransactions: 10,
        totalCommission: 50.0,
        totalReceivedAmount: 1000.0,
        receiveCount: 3,
        totalBalance: 500.0,
      );
      final todayBefore = DailyStatsModel.empty('2026-06-05').copyWith(
        totalTransactions: 5,
        totalCommission: 10.0,
        receiveCount: 2,
        totalReceivedAmount: 800.0,
      );

      provider.rollbackStats(summaryBefore, todayBefore);

      provider.addTransactionOptimistically({
        'amount': 200.0,
        'commission': 0.0,
        'type': 'deposit',
      });

      expect(provider.dashboardSummary!.totalTransactions, 10);
      expect(provider.dashboardSummary!.totalCommission, 50.0);
      expect(provider.dashboardSummary!.totalReceivedAmount, 1000.0);
      expect(provider.dashboardSummary!.receiveCount, 3);
      expect(provider.dashboardSummary!.totalBalance, 500.0);

      expect(provider.todayStats!.totalTransactions, 5);
      expect(provider.todayStats!.totalCommission, 10.0);
      expect(provider.todayStats!.receiveCount, 2);
      expect(provider.todayStats!.totalReceivedAmount, 800.0);
    });

    test(
        'addTransactionOptimistically with debit and serviceFee should deduct (amount + serviceFee) from totalBalance',
        () {
      final summaryBefore = StatsSummaryModel.empty().copyWith(
        totalTransactions: 10,
        totalCommission: 50.0,
        totalSentAmount: 1000.0,
        sendCount: 3,
        totalBalance: 2000.0,
      );
      final todayBefore = DailyStatsModel.empty('2026-06-05').copyWith(
        totalTransactions: 5,
        totalCommission: 10.0,
        sendCount: 2,
        totalSentAmount: 800.0,
      );

      provider.rollbackStats(summaryBefore, todayBefore);

      // Debit: amount = 300.0, serviceFee = 15.0, commission = 10.0
      provider.addTransactionOptimistically({
        'amount': 300.0,
        'commission': 10.0,
        'serviceFee': 15.0,
        'type': 'debit',
      });

      // Total balance must be: 2000.0 - (300.0 + 15.0) = 1685.0
      expect(provider.dashboardSummary!.totalBalance, 1685.0);
      expect(provider.dashboardSummary!.totalTransactions, 11);
      expect(provider.dashboardSummary!.totalCommission, 60.0);
      expect(provider.dashboardSummary!.totalSentAmount, 1300.0);
      expect(provider.dashboardSummary!.sendCount, 4);
    });

    test(
        'updateLocalStats with debit and serviceFee should deduct (amount + serviceFee) from totalBalance',
        () {
      final summaryBefore = StatsSummaryModel.empty().copyWith(
        totalTransactions: 10,
        totalCommission: 50.0,
        totalSentAmount: 1000.0,
        sendCount: 3,
        totalBalance: 2000.0,
      );
      final todayBefore = DailyStatsModel.empty('2026-06-05').copyWith(
        totalTransactions: 5,
        totalCommission: 10.0,
        sendCount: 2,
        totalSentAmount: 800.0,
      );

      provider.rollbackStats(summaryBefore, todayBefore);

      provider.updateLocalStats(
        300.0,
        'debit',
        commission: 10.0,
        serviceFee: 15.0,
      );

      // Total balance must be: 2000.0 - (300.0 + 15.0) = 1685.0
      expect(provider.dashboardSummary!.totalBalance, 1685.0);
    });
  });

  group('StatisticsProvider Employee Guard', () {
    late MockAuthProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthProvider();
    });

    test(
        'fetchDashboardStats returns early without fetching stats when employee lacks viewDashboardStats permission',
        () async {
      final employeeNoStats = UserModel(
        userId: 'emp1',
        firebaseUid: 'uid1',
        storeId: storeId,
        role: UserRole.employee,
        fullName: 'Emp No Stats',
        isActive: true,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        permissions: UserPermissions(viewDashboardStats: false),
      );

      when(() => mockAuthProvider.currentUser).thenReturn(employeeNoStats);

      reset(mockStatsRepo);

      final prov = StatisticsProvider(
        statsRepository: mockStatsRepo,
        authProvider: mockAuthProvider,
      );

      prov.setStoreId(storeId);
      await Future.delayed(Duration.zero);

      verifyNever(() => mockStatsRepo.getStatsSummary(any()));
      verifyNever(() => mockStatsRepo.fetchTodayStats(any()));
    });

    test('fetchDashboardStats proceeds when user is owner', () async {
      final owner = UserModel(
        userId: 'owner1',
        firebaseUid: 'uid2',
        storeId: storeId,
        role: UserRole.owner,
        fullName: 'Owner User',
        isActive: true,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuthProvider.currentUser).thenReturn(owner);

      reset(mockStatsRepo);
      when(() => mockStatsRepo.getStatsSummary(storeId))
          .thenAnswer((_) async => StatsSummaryModel.empty());
      when(() => mockStatsRepo.fetchTodayStats(storeId))
          .thenAnswer((_) async => DailyStatsModel.empty('2026-06-05'));

      final prov = StatisticsProvider(
        statsRepository: mockStatsRepo,
        authProvider: mockAuthProvider,
      );

      prov.setStoreId(storeId);
      await Future.delayed(Duration.zero);

      verify(() => mockStatsRepo.getStatsSummary(storeId)).called(1);
    });

    test(
        'fetchDashboardStats proceeds when employee has viewDashboardStats permission',
        () async {
      final employeeWithStats = UserModel(
        userId: 'emp2',
        firebaseUid: 'uid3',
        storeId: storeId,
        role: UserRole.employee,
        fullName: 'Emp With Stats',
        isActive: true,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        permissions: UserPermissions(viewDashboardStats: true),
      );

      when(() => mockAuthProvider.currentUser).thenReturn(employeeWithStats);

      reset(mockStatsRepo);
      when(() => mockStatsRepo.getStatsSummary(storeId))
          .thenAnswer((_) async => StatsSummaryModel.empty());
      when(() => mockStatsRepo.fetchTodayStats(storeId))
          .thenAnswer((_) async => DailyStatsModel.empty('2026-06-05'));

      final prov = StatisticsProvider(
        statsRepository: mockStatsRepo,
        authProvider: mockAuthProvider,
      );

      prov.setStoreId(storeId);
      await Future.delayed(Duration.zero);

      verify(() => mockStatsRepo.getStatsSummary(storeId)).called(1);
    });
  });
}

class MockAuthProvider extends Mock implements AuthProvider {}
