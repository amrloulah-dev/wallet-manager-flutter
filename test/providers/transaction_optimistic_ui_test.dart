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

class MockTransactionRepository extends Mock implements TransactionRepository {}
class MockAuthProvider extends Mock implements AuthProvider {}
class MockStatsRepository extends Mock implements StatsRepository {}
class MockWalletRepository extends Mock implements WalletRepository {}
class MockWalletProvider extends Mock implements WalletProvider {}
class FakeTransactionModel extends Fake implements TransactionModel {}

void main() {
  late MockTransactionRepository mockTxRepo;
  late MockWalletRepository mockWalletRepo;
  late MockAuthProvider mockAuth;
  late MockWalletProvider mockWalletProvider;
  late MockStatsRepository mockStatsRepo;
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
  });

  setUp(() async {
    AppErrorHandler.isTestMode = true;
    AnalyticsService.isTestMode = true;
    mockTxRepo = MockTransactionRepository();
    mockWalletRepo = MockWalletRepository();
    mockAuth = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();
    mockStatsRepo = MockStatsRepository();

    final sl = GetIt.instance;
    await sl.reset();
    sl.registerLazySingleton<StatsRepository>(() => mockStatsRepo);

    when(() => mockAuth.currentStoreId).thenReturn(storeId);
    when(() => mockAuth.isOwner).thenReturn(true);
    when(() => mockAuth.currentUser).thenReturn(mockUser);

    when(() => mockWalletRepo.getWalletById(walletId, expectedStoreId: storeId))
        .thenAnswer((_) async => mockWallet);
    when(() => mockWalletProvider.isWalletFrozenSync(walletId)).thenReturn(false);

    when(() => mockStatsRepo.fetchTodayStats(storeId))
        .thenAnswer((_) async => DailyStatsModel.empty('2026-06-05'));

    when(() => mockTxRepo.getTransactionsByDateRange(any(), any(), any(), lastDocument: any(named: 'lastDocument')))
        .thenAnswer((_) async => PaginatedResult<TransactionModel>(items: [], lastDocument: null));

    provider = TransactionProvider(
      transactionRepository: mockTxRepo,
      walletRepository: mockWalletRepo,
    );
    provider.updateWalletProvider(mockWalletProvider);
    provider.updateAuthState(mockAuth);
    provider.setStoreId(storeId);
  });

  group('TransactionProvider Optimistic UI Tests', () {
    test('createTransaction should generate client-side UUID and insert to local list immediately', () async {
      final txCompleter = Completer<void>();
      when(() => mockTxRepo.createTransaction(any()))
          .thenAnswer((_) => txCompleter.future);
      when(() => mockWalletProvider.applyLocalDeduction(any(), any(), any())).thenReturn(null);

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
      expect(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$').hasMatch(optimisticTx.transactionId), isTrue);
      expect(optimisticTx.amount, 100.0);

      // Verify local wallet balance update was triggered
      verify(() => mockWalletProvider.applyLocalDeduction(walletId, 100.0, true)).called(1);

      // Complete the repository future
      txCompleter.complete();
      final result = await createFuture;
      expect(result, isTrue);
    });

    test('failed createTransaction should trigger rollback to snapshot', () async {
      when(() => mockTxRepo.createTransaction(any()))
          .thenThrow(Exception('Firestore write failed'));
      when(() => mockWalletProvider.applyLocalDeduction(any(), any(), any())).thenReturn(null);

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

      // Balance rollback should be triggered (compensating update)
      // Since it was updated with true (send), it should be compensated with false (receive)
      verify(() => mockWalletProvider.applyLocalDeduction(walletId, 100.0, true)).called(1);
      verify(() => mockWalletProvider.applyLocalDeduction(walletId, 100.0, false)).called(1);
    });

    test('summaries should be computed dynamically from local list after initial load', () async {
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) async {});
      when(() => mockWalletProvider.applyLocalDeduction(any(), any(), any())).thenReturn(null);

      // Initial stats mock
      final summaryStats = DailyStatsModel.empty('2026-06-05').copyWith(
        transactionCount: 2,
        totalCommission: 10.0,
      );
      when(() => mockStatsRepo.fetchTodayStats(storeId)).thenAnswer((_) async => summaryStats);

      await provider.fetchTodaySummary();
      expect(provider.summary['totalTransactions'], 2);
      expect(provider.summary['totalCommission'], 10.0);

      // Adding transaction should dynamically update summaries
      await provider.createTransaction(
        walletId: walletId,
        transactionType: TransactionType.debit, // Sent
        amount: 200.0,
        commission: 5.0,
      );

      // Summaries should increase dynamically
      expect(provider.summary['totalTransactions'], 3);
      expect(provider.summary['totalCommission'], 15.0);
    });

    test('fetchInitialTransactions with forceRefresh should preserve pending optimistic transactions', () async {
      final txCompleter = Completer<void>();
      when(() => mockTxRepo.createTransaction(any())).thenAnswer((_) => txCompleter.future);
      when(() => mockWalletProvider.applyLocalDeduction(any(), any(), any())).thenReturn(null);
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
      when(() => mockTxRepo.getTransactionsByDateRange(storeId, any(), any(), lastDocument: any(named: 'lastDocument')))
          .thenAnswer((_) async => PaginatedResult<TransactionModel>(items: [serverTx], lastDocument: null));

      // Trigger pull-to-refresh
      await provider.fetchInitialTransactions(forceRefresh: true);

      // Verify that the local list now has the fetched server transaction AND the pending transaction!
      expect(provider.transactions.length, 2);
      expect(provider.transactions.any((t) => t.transactionId == 't_server'), isTrue);
      expect(provider.transactions.any((t) => t.transactionId == pendingTxId), isTrue);

      // Clean up/Complete pending write
      txCompleter.complete();
      await createFuture;
    });
  });
}
