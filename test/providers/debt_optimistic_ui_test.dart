import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockDebtRepository extends Mock implements DebtRepository {}

class MockStatisticsProvider extends Mock implements StatisticsProvider {}

class FakeDebtModel extends Fake implements DebtModel {}

void main() {
  late MockAuthProvider mockAuth;
  late MockDebtRepository mockDebtRepo;
  late MockStatisticsProvider mockStatsProvider;
  late DebtProvider provider;

  const storeId = 's1';
  final mockUser = UserModel(
    userId: 'u1',
    storeId: storeId,
    role: UserRole.owner,
    fullName: 'Test Owner',
    createdAt: DateTime.now(),
    lastLogin: DateTime.now(),
  );

  final initialDebt = DebtModel(
    debtId: 'd_initial',
    storeId: storeId,
    customerName: 'Test Customer',
    customerPhone: '010',
    debtType: DebtType.transaction,
    amountDue: 300.0,
    totalAmount: 300.0,
    createdBy: 'u1',
    debtStatus: DebtStatus.open,
    debtDate: DateTime.now(),
    createdAt: DateTime.now(),
  );

  setUpAll(() {
    registerFallbackValue(FakeDebtModel());
    registerFallbackValue(DateTime(2020));
  });

  setUp(() async {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockAuth = MockAuthProvider();
    mockDebtRepo = MockDebtRepository();
    mockStatsProvider = MockStatisticsProvider();

    final sl = GetIt.instance;
    await sl.reset();
    sl.registerLazySingleton<StatisticsProvider>(() => mockStatsProvider);

    when(() => mockAuth.currentStoreId).thenReturn(storeId);
    when(() => mockAuth.isOwner).thenReturn(true);
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    when(() => mockStatsProvider.addDebtOptimistically(
        amount: any(named: 'amount'))).thenReturn(null);
    when(() => mockStatsProvider.settleDebtOptimistically(
        amount: any(named: 'amount'))).thenReturn(null);
    when(() => mockStatsProvider.payPartialDebtOptimistically(
        amount: any(named: 'amount'))).thenReturn(null);
    when(() => mockStatsProvider.rollbackStats(any(), any())).thenReturn(null);
    when(() => mockStatsProvider.dashboardSummary).thenReturn(
      StatsSummaryModel(
        openDebtsCount: 1,
        paidDebtsCount: 0,
        totalOpenAmount: 300.0,
        totalPaidAmount: 0.0,
        lastUpdated: DateTime.now(),
      ),
    );
    when(() => mockStatsProvider.todayStats)
        .thenReturn(DailyStatsModel.empty('2026-06-05'));

    when(() => mockDebtRepo.getDebtByCustomerPhone(storeId, any()))
        .thenAnswer((_) async => null);
    when(() => mockDebtRepo.getDebtsByDateRange(
              storeId,
              any(),
              any(),
              lastDocument: any(named: 'lastDocument'),
              debtType: any(named: 'debtType'),
              debtStatus: any(named: 'debtStatus'),
            ))
        .thenAnswer((_) async => PaginatedResult<DebtModel>(
            items: [initialDebt], lastDocument: null));

    when(() => mockDebtRepo.fetchDebtStatistics(
          storeId: storeId,
          type: any(named: 'type'),
        )).thenAnswer((_) async => {
          'openCount': 1,
          'paidCount': 0,
          'openTotal': 300.0,
          'paidTotal': 0.0,
        });

    provider = DebtProvider(
      authProvider: mockAuth,
      debtRepository: mockDebtRepo,
      storeId: storeId,
    );
  });

  group('DebtProvider Optimistic UI Tests', () {
    test(
        'createDebt should generate client-side UUID and insert to local list immediately',
        () async {
      final createCompleter = Completer<void>();
      when(() => mockDebtRepo.createDebt(any()))
          .thenAnswer((_) => createCompleter.future);

      await provider.fetchInitialDebts();
      expect(provider.debts.length, 1);

      // Create new debt
      final createFuture = provider.createDebt(
        customerName: 'New Customer',
        customerPhone: '011',
        debtType: DebtType.transaction,
        amountDue: 200.0,
        createdBy: 'u1',
      );

      // Yield control
      await Future.delayed(const Duration(milliseconds: 10));

      // Optimistically added
      expect(provider.debts.length, 2);
      final newDebt = provider.debts.firstWhere((d) => d.debtId != 'd_initial');

      // ID must be a UUID
      expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
              .hasMatch(newDebt.debtId),
          isTrue);
      expect(newDebt.amountDue, 200.0);
      expect(provider.debtMap.containsKey(newDebt.debtId), isTrue);

      verify(() => mockStatsProvider.addDebtOptimistically(amount: 200.0))
          .called(1);

      createCompleter.complete();
      final result = await createFuture;
      expect(result, isTrue);
    });

    test('createDebt rollback on failure', () async {
      when(() => mockDebtRepo.createDebt(any()))
          .thenThrow(Exception('Firestore write failed'));

      await provider.fetchInitialDebts();
      expect(provider.debts.length, 1);

      final result = provider.createDebt(
        customerName: 'New Customer',
        customerPhone: '011',
        debtType: DebtType.transaction,
        amountDue: 200.0,
        createdBy: 'u1',
      );

      final success = await result;
      expect(success, isFalse);

      // Reverted to 1 debt
      expect(provider.debts.length, 1);
      expect(provider.debts.first.debtId, 'd_initial');
      verify(() => mockStatsProvider.rollbackStats(any(), any())).called(1);
    });

    test(
        'payPartialDebt (partial payment) optimistic amountDue change and rollback',
        () async {
      final payCompleter = Completer<void>();
      when(() => mockDebtRepo.processPayment('d_initial', 100.0, 'u1'))
          .thenAnswer((_) => payCompleter.future);

      await provider.fetchInitialDebts();
      expect(provider.debts.first.amountDue, 300.0);

      final payFuture = provider.payPartialDebt('d_initial', 100.0, 'u1');

      await Future.delayed(const Duration(milliseconds: 10));

      // Optimistically deducted locally
      expect(provider.debts.first.amountDue, 200.0);
      expect(provider.debts.first.debtStatus, DebtStatus.open);

      verify(() =>
              mockStatsProvider.payPartialDebtOptimistically(amount: 100.0))
          .called(1);

      payCompleter.complete();
      final result = await payFuture;
      expect(result, isTrue);
    });

    test('payPartialDebt rollback on failure', () async {
      when(() => mockDebtRepo.processPayment('d_initial', 100.0, 'u1'))
          .thenThrow(Exception('Payment failed'));

      await provider.fetchInitialDebts();
      expect(provider.debts.first.amountDue, 300.0);

      final result = await provider.payPartialDebt('d_initial', 100.0, 'u1');

      expect(result, isFalse);
      // Reverted
      expect(provider.debts.first.amountDue, 300.0);
    });

    test(
        'payPartialDebt (full payment/settlement) optimistic status change and filtering',
        () async {
      final payCompleter = Completer<void>();
      when(() => mockDebtRepo.processPayment('d_initial', 300.0, 'u1'))
          .thenAnswer((_) => payCompleter.future);

      // Set filter to open
      provider.setFilter('open');
      await provider.fetchInitialDebts();
      expect(provider.debts.length, 1);

      final payFuture = provider.payPartialDebt('d_initial', 300.0, 'u1');

      await Future.delayed(const Duration(milliseconds: 10));

      // Instantly filtered out from 'open' list
      expect(provider.debts, isEmpty);
      verify(() => mockStatsProvider.settleDebtOptimistically(amount: 300.0))
          .called(1);

      payCompleter.complete();
      final result = await payFuture;
      expect(result, isTrue);
    });

    test('payPartialDebt (full payment/settlement) rollback on failure',
        () async {
      when(() => mockDebtRepo.processPayment('d_initial', 300.0, 'u1'))
          .thenThrow(Exception('Payment failed'));

      provider.setFilter('open');
      await provider.fetchInitialDebts();
      expect(provider.debts.length, 1);

      final result = await provider.payPartialDebt('d_initial', 300.0, 'u1');

      expect(result, isFalse);
      // Reverted back to the list
      expect(provider.debts.length, 1);
      expect(provider.debts.first.debtId, 'd_initial');
    });

    test('dynamic debt summary getters', () async {
      await provider.fetchInitialDebts();
      expect(provider.summary['openDebtsCount'], 1);
      expect(provider.summary['totalOpenAmount'], 300.0);

      // Stub createDebt to succeed
      when(() => mockDebtRepo.createDebt(any())).thenAnswer((_) async {});

      await provider.createDebt(
        customerName: 'New',
        customerPhone: '012',
        debtType: DebtType.transaction,
        amountDue: 200.0,
        createdBy: 'u1',
      );

      // Should be computed dynamically
      expect(provider.summary['openDebtsCount'], 2);
      expect(provider.summary['totalOpenAmount'], 500.0);
    });

    test('fetch shield behavior - blocks fetch for 5 seconds after activation',
        () async {
      // Injects data and triggers activateFetchShield (this happens inside provider when needed, or we can invoke it)
      provider
          .activateFetchShieldExternal(); // Custom helper or we test it by triggering a successful write

      // Should block fetchInitialDebts
      await provider.fetchInitialDebts();
      // Verify repository was NOT called because of fetch shield
      verifyNever(() => mockDebtRepo.getDebtsByDateRange(
            any(),
            any(),
            any(),
            lastDocument: any(named: 'lastDocument'),
            debtType: any(named: 'debtType'),
            debtStatus: any(named: 'debtStatus'),
          ));
    });

    test(
        'fetchInitialDebts with forceRefresh should preserve pending optimistic debts',
        () async {
      final createCompleter = Completer<void>();
      when(() => mockDebtRepo.createDebt(any()))
          .thenAnswer((_) => createCompleter.future);

      await provider.fetchInitialDebts();
      expect(provider.debts.length, 1);

      // Create debt, keeping it pending
      final createFuture = provider.createDebt(
        customerName: 'Pending Customer',
        customerPhone: '01222',
        debtType: DebtType.transaction,
        amountDue: 150.0,
        createdBy: 'u1',
      );

      await Future.delayed(Duration.zero);

      // We have 1 pending debt in provider's local list (total 2)
      expect(provider.debts.length, 2);
      final pendingDebtId =
          provider.debts.firstWhere((d) => d.debtId != 'd_initial').debtId;

      // Mock repository response for fetchInitialDebts
      final serverDebt = DebtModel(
        debtId: 'd_server',
        storeId: storeId,
        customerName: 'Server Customer',
        customerPhone: '01333',
        debtType: DebtType.transaction,
        amountDue: 400.0,
        totalAmount: 400.0,
        createdBy: 'u1',
        debtStatus: DebtStatus.open,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      when(() => mockDebtRepo.getDebtsByDateRange(
                storeId,
                any(),
                any(),
                lastDocument: any(named: 'lastDocument'),
                debtType: any(named: 'debtType'),
                debtStatus: any(named: 'debtStatus'),
              ))
          .thenAnswer((_) async => PaginatedResult<DebtModel>(
              items: [serverDebt], lastDocument: null));

      // Trigger pull-to-refresh
      await provider.fetchInitialDebts(forceRefresh: true);

      // Verify that the local list now has the fetched server debt AND the pending debt!
      expect(provider.debts.length, 2);
      expect(provider.debts.any((d) => d.debtId == 'd_server'), isTrue);
      expect(provider.debts.any((d) => d.debtId == pendingDebtId), isTrue);

      // Clean up/Complete pending write
      createCompleter.complete();
      await createFuture;
    });
  });
}
