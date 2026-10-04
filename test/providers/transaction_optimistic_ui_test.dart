import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/core/utils/date_helper.dart';

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockAuthProvider extends Mock implements AuthProvider {}

class MockStatsRepository extends Mock implements StatsRepository {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockWalletProvider extends Mock implements WalletProvider {}

class MockStatisticsProvider extends Mock implements StatisticsProvider {}

class FakeTransactionModel extends Fake implements TransactionModel {}

class FakeWalletModel extends Fake implements WalletModel {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockWalletRepository mockWalletRepo;
  late MockAuthProvider mockAuth;
  late MockWalletProvider mockWalletProvider;
  late MockStatsRepository mockStatsRepo;
  late MockStatisticsProvider mockStatsProvider;
  late TransactionProvider provider;

  const storeId = 's1';
  const walletId = 'w1';

  final mockWallet = WalletModel(
    walletId: walletId,
    storeId: storeId,
    phoneNumber: '012',
    walletType: WalletType.vodafoneCash,
    walletStatus: WalletStatus.active,
    balance: 500.0,
    isActive: true,
    createdBy: 'u1',
    sendLimits: WalletLimits(
        dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
    receiveLimits: WalletLimits(
        dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
    stats: WalletStats(
        totalTransactions: 0,
        totalCommission: 0,
        totalSentAmount: 0,
        totalReceivedAmount: 0),
  );

  final mockUser = UserModel(
    userId: 'u1',
    storeId: storeId,
    role: UserRole.owner,
    fullName: 'Test Owner',
    createdAt: DateTime.now(),
    lastLogin: DateTime.now(),
  );

  setUpAll(() {
    registerFallbackValue(UserRole.employee);
    registerFallbackValue(FakeTransactionModel());
    registerFallbackValue(FakeWalletModel());
  });

  setUp(() async {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockTxRepo = MockTransactionRepository();
    mockWalletRepo = MockWalletRepository();
    mockAuth = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();
    mockStatsRepo = MockStatsRepository();
    mockStatsProvider = MockStatisticsProvider();

    final sl = GetIt.instance;
    await sl.reset();
    sl.registerLazySingleton<StatsRepository>(() => mockStatsRepo);
    sl.registerLazySingleton<StatisticsProvider>(() => mockStatsProvider);
    sl.registerLazySingleton<WalletProvider>(() => mockWalletProvider);

    when(() => mockAuth.currentStoreId).thenReturn(storeId);
    when(() => mockAuth.isOwner).thenReturn(true);
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    when(() => mockWalletRepo.getWalletById(walletId, expectedStoreId: storeId))
        .thenAnswer((_) async => mockWallet);
    when(() => mockWalletProvider.isWalletFrozenSync(walletId))
        .thenReturn(false);
    when(() => mockWalletProvider.walletMap).thenReturn({walletId: mockWallet});
    when(() => mockWalletProvider.rollbackWallet(any())).thenReturn(null);
    when(() => mockWalletProvider.updateLocalWalletBalance(
          walletId: any(named: 'walletId'),
          amount: any(named: 'amount'),
          isIncome: any(named: 'isIncome'),
          serviceFee: any(named: 'serviceFee'),
        )).thenReturn(null);
    when(() => mockWalletProvider.updateLocalBalance(any(), any(), any(),
        serviceFee: any(named: 'serviceFee'))).thenReturn(null);
    when(() => mockStatsProvider.applyTransactionLocally(any(), any(),
        commission: any(named: 'commission'))).thenReturn(null);
    when(() => mockStatsProvider.updateLocalStats(any(), any(),
        commission: any(named: 'commission'))).thenReturn(null);
    when(() => mockStatsProvider.rollbackStats(any(), any())).thenReturn(null);

    when(() => mockStatsRepo.fetchTodayStats(storeId))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-06-05'));

    when(() => mockStatsRepo.getStatsSummary(any()))
        .thenAnswer((_) async => StatsSummaryModel.empty());

    when(() => mockTxRepo.getTransactionsByDateRange(any(), any(), any(),
            lastDocument: any(named: 'lastDocument')))
        .thenAnswer((_) async =>
            PaginatedResult<TransactionModel>(items: [], lastDocument: null));

    provider = TransactionProvider(
      transactionRepository: mockTxRepo,
      walletRepository: mockWalletRepo,
    );
    provider.updateWalletProvider(mockWalletProvider);
    provider.updateAuthState(mockAuth);
    provider.setStoreId(storeId);
  });

  group('TransactionProvider Optimistic UI Tests', () {
    test(
        'createTransaction should generate client-side UUID and insert to local list immediately',
        () async {
      final txCompleter = Completer<void>();
      when(() => mockTxRepo.createTransaction(any()))
          .thenAnswer((_) => txCompleter.future);
      when(() => mockWalletProvider.updateLocalWalletBalance(
            walletId: any(named: 'walletId'),
            amount: any(named: 'amount'),
            isIncome: any(named: 'isIncome'),
            serviceFee: any(named: 'serviceFee'),
          )).thenReturn(null);

      // Create transaction (returns a Future that is not complete yet)
      final createFuture = provider.createTransaction(
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 2.0,
      );

      // Yield control to let async validation and wallet loading complete
      await Future.delayed(Duration.zero);

      // Verify that before the Firestore write completes, the transaction is added to local state
      expect(provider.transactions, isNotEmpty);
      final optimisticTx = provider.transactions.first;

      // ID should be a UUID
      expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
              .hasMatch(optimisticTx.transactionId),
          isTrue);
      expect(optimisticTx.amount, 100.0);

      // Verify local wallet balance update was triggered
      verify(() => mockWalletProvider.updateLocalBalance(
            walletId,
            100.0,
            TransactionType.debit,
            serviceFee: 0.0,
          )).called(1);

      // Complete the repository future
      txCompleter.complete();
      final result = await createFuture;
      expect(result, isTrue);
    });

    test('failed createTransaction should trigger rollback to snapshot',
        () async {
      when(() => mockTxRepo.createTransaction(any()))
          .thenThrow(Exception('Firestore write failed'));
      when(() => mockWalletProvider.updateLocalBalance(
            any(),
            any(),
            any(),
            serviceFee: any(named: 'serviceFee'),
          )).thenReturn(null);

      // We start with 0 transactions in list
      expect(provider.transactions, isEmpty);

      final result = await provider.createTransaction(
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 2.0,
      );

      // Write failed, should return false
      expect(result, isFalse);

      // State should have rolled back, list should be empty again
      expect(provider.transactions, isEmpty);

      // Balance rollback should be triggered via snapshot rollback
      verify(() => mockWalletProvider.updateLocalBalance(
            walletId,
            100.0,
            TransactionType.debit,
            serviceFee: 0.0,
          )).called(1);
      verify(() => mockWalletProvider.rollbackWallet(any())).called(1);
    });

    test(
        'summaries should be computed dynamically from local list after initial load',
        () async {
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});
      when(() => mockWalletProvider.applyLocalDeduction(any(), any(), any()))
          .thenReturn(null);

      // Initial stats mock
      final todayStats = DailyStatsModel(
        date: DateHelper.getCurrentDateString(),
        totalTransactions: 2,
        totalCommission: 10.0,
      );
      when(() => mockStatsRepo.fetchTodayStats(storeId))
          .thenAnswer((_) async => todayStats);

      final testProvider = TransactionProvider(
        transactionRepository: mockTxRepo,
        statsRepository: mockStatsRepo,
        walletRepository: mockWalletRepo,
        storeId: storeId,
      );
      testProvider.updateWalletProvider(mockWalletProvider);
      testProvider.updateAuthState(mockAuth);

      await testProvider.fetchTodaySummary();
      expect(testProvider.summary['totalTransactions'], 2);
      expect(testProvider.summary['totalCommission'], 10.0);

      // Now fetch initial transactions (to set _hasFetchedInitial to true)
      final serverTx = TransactionModel(
        transactionId: 't_server',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.credit,
        amount: 50.0,
        commission: 1.0,
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        createdBy: 'u1',
      );
      when(() => mockTxRepo.getTransactionsByDateRange(storeId, any(), any(),
              lastDocument: any(named: 'lastDocument')))
          .thenAnswer((_) async => PaginatedResult<TransactionModel>(
              items: [serverTx], lastDocument: null));

      await testProvider.fetchInitialTransactions(forceRefresh: true);

      // Summaries should now be derived from local list
      expect(testProvider.summary['totalTransactions'], 1);
      expect(testProvider.summary['totalCommission'], 1.0);
    });

    test(
        'fetchInitialTransactions with forceRefresh should preserve pending optimistic transactions',
        () async {
      final txCompleter = Completer<void>();
      when(() => mockTxRepo.createTransaction(any()))
          .thenAnswer((_) => txCompleter.future);
      when(() => mockWalletProvider.applyLocalDeduction(any(), any(), any()))
          .thenReturn(null);
      when(() => mockWalletProvider.clearPendingWallet(any())).thenReturn(null);

      // Create transaction, keeping it pending
      final createFuture = provider.createTransaction(
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 2.0,
      );

      await Future.delayed(Duration.zero);

      // We have 1 pending transaction in provider's local list
      expect(provider.transactions.length, 1);
      final pendingTxId = provider.transactions.first.transactionId;

      // Mock repository response for fetchInitialTransactions
      final serverTx = TransactionModel(
        transactionId: 't_server',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.credit,
        amount: 50.0,
        commission: 1.0,
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
        createdBy: 'u1',
      );
      when(() => mockTxRepo.getTransactionsByDateRange(storeId, any(), any(),
              lastDocument: any(named: 'lastDocument')))
          .thenAnswer((_) async => PaginatedResult<TransactionModel>(
              items: [serverTx], lastDocument: null));

      // Trigger pull-to-refresh
      await provider.fetchInitialTransactions(forceRefresh: true);

      // Verify that the local list now has the fetched server transaction AND the pending transaction!
      expect(provider.transactions.length, 2);
      expect(provider.transactions.any((t) => t.transactionId == 't_server'),
          isTrue);
      expect(provider.transactions.any((t) => t.transactionId == pendingTxId),
          isTrue);

      // Clean up/Complete pending write
      txCompleter.complete();
      await createFuture;
    });

    test(
        'dynamic summary getters (totalSent, totalReceived, totalCommission) compute correctly from local list',
        () {
      final tx1 = TransactionModel(
        transactionId: 't1',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 2.0,
        createdBy: 'u1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      final tx2 = TransactionModel(
        transactionId: 't2',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.credit,
        amount: 50.0,
        commission: 1.0,
        createdBy: 'u1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      provider.insertTransactionLocally(tx1);
      provider.insertTransactionLocally(tx2);

      expect(provider.totalSent, 100.0);
      expect(provider.totalReceived, 50.0);
      expect(provider.totalCommission, 3.0);
    });

    test(
        'fetchTodaySummary on initial load should fetch from daily_stats document',
        () async {
      final todayStats = DailyStatsModel(
        date: DateHelper.getCurrentDateString(),
        totalTransactions: 5,
        totalCommission: 25.0,
        totalSentAmount: 200.0,
        totalReceivedAmount: 300.0,
        sendCount: 3,
        receiveCount: 2,
      );
      when(() => mockStatsRepo.fetchTodayStats(storeId))
          .thenAnswer((_) async => todayStats);

      final newProvider = TransactionProvider(
        transactionRepository: mockTxRepo,
        statsRepository: mockStatsRepo,
        walletRepository: mockWalletRepo,
        storeId: storeId,
      );
      newProvider.updateAuthState(mockAuth);

      clearInteractions(mockStatsRepo);

      await newProvider.fetchTodaySummary();

      expect(newProvider.summary['totalTransactions'], 5);
      expect(newProvider.summary['totalCommission'], 25.0);
      expect(newProvider.summary['totalSendAmount'], 200.0);
      expect(newProvider.summary['totalReceiveAmount'], 300.0);
      expect(newProvider.summary['sendCount'], 3);
      expect(newProvider.summary['receiveCount'], 2);

      verify(() => mockStatsRepo.fetchTodayStats(storeId)).called(1);
    });

    test(
        'transaction model toFirestore should serialize createdAt and transactionDate as FieldValue.serverTimestamp()',
        () {
      final now = DateTime.now();
      final tx = TransactionModel(
        transactionId: 't1',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 2.0,
        createdBy: 'u1',
        transactionDate: now,
        createdAt: now,
      );

      expect(tx.transactionDate, now);
      expect(tx.createdAt, now);

      final firestoreData = tx.toFirestore();
      expect(firestoreData['createdAt'], isA<FieldValue>());
      expect(firestoreData['transactionDate'], isA<FieldValue>());
    });

    test(
        'local summary derivation should ignore non-debit/non-credit transactions',
        () async {
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});

      final txDebit = TransactionModel(
        transactionId: 't1',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 2.0,
        createdBy: 'u1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      final txCredit = TransactionModel(
        transactionId: 't2',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.credit,
        amount: 50.0,
        commission: 1.0,
        createdBy: 'u1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      final txDeposit = TransactionModel(
        transactionId: 't3',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.deposit,
        amount: 500.0,
        commission: 0.0,
        createdBy: 'u1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      final txOther = TransactionModel(
        transactionId: 't4',
        storeId: storeId,
        walletId: walletId,
        transactionType: TransactionType.other,
        amount: 10.0,
        commission: 0.0,
        createdBy: 'u1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      provider.insertTransactionLocally(txDebit);
      provider.insertTransactionLocally(txCredit);
      provider.insertTransactionLocally(txDeposit);
      provider.insertTransactionLocally(txOther);

      when(() => mockTxRepo.getTransactionsByDateRange(storeId, any(), any(),
              lastDocument: any(named: 'lastDocument')))
          .thenAnswer((_) async => PaginatedResult<TransactionModel>(
              items: [txDebit, txCredit, txDeposit, txOther],
              lastDocument: null));

      await provider.fetchInitialTransactions(forceRefresh: true);

      expect(provider.summary['totalTransactions'], 2);
      expect(provider.summary['sendCount'], 1);
      expect(provider.summary['receiveCount'], 1);
      expect(provider.summary['totalSendAmount'], 100.0);
      expect(provider.summary['totalReceiveAmount'], 50.0);
      expect(provider.summary['totalCommission'], 3.0);
    });
  });
}
