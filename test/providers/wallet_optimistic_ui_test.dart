import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/wallet_cache_manager.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/data/models/paginated_result.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockWalletCacheManager extends Mock implements WalletCacheManager {}

class MockWalletUseCase extends Mock implements WalletUseCase {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class FakeWalletModel extends Fake implements WalletModel {}

void main() {
  late MockAuthProvider mockAuth;
  late MockWalletRepository mockWalletRepo;
  late MockTransactionRepository mockTransactionRepo;
  late MockWalletCacheManager mockCacheManager;
  late MockWalletUseCase mockUseCase;
  late MockSubscriptionProvider mockSubProvider;
  late WalletProvider provider;

  const storeId = 's1';
  final mockUser = UserModel(
    userId: 'u1',
    storeId: storeId,
    role: UserRole.owner,
    fullName: 'Test Owner',
    createdAt: DateTime.now(),
    lastLogin: DateTime.now(),
  );

  final initialWallet = WalletModel(
    walletId: 'w_initial',
    storeId: storeId,
    phoneNumber: '010',
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

  setUpAll(() {
    registerFallbackValue(FakeWalletModel());
  });

  setUp(() {
    AppErrorHandler.isTestMode = true;
    mockAuth = MockAuthProvider();
    mockWalletRepo = MockWalletRepository();
    mockTransactionRepo = MockTransactionRepository();
    mockCacheManager = MockWalletCacheManager();
    mockUseCase = MockWalletUseCase();
    mockSubProvider = MockSubscriptionProvider();

    when(() => mockAuth.currentStoreId).thenReturn(storeId);
    when(() => mockAuth.isOwner).thenReturn(true);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.ensureUserLoaded()).thenAnswer((_) async => mockUser);
    when(() => mockAuth.currentUserId).thenReturn('u1');

    when(() => mockUseCase.validatePermission(any()))
        .thenAnswer((_) async => mockUser);
    when(() => mockUseCase.calculateFrozenWallets(
          wallets: any(named: 'wallets'),
          subscriptionProvider: any(named: 'subscriptionProvider'),
          storeId: any(named: 'storeId'),
        )).thenReturn(<String>{});

    when(() => mockCacheManager.cacheWallets(any())).thenAnswer((_) async {});
    when(() => mockWalletRepo.getAllWallets(storeId)).thenAnswer((_) async =>
        PaginatedResult<WalletModel>(
            items: [initialWallet], lastDocument: null));

    when(() => mockSubProvider.canAddWallet(any())).thenReturn(true);

    provider = WalletProvider(
      authProvider: mockAuth,
      walletRepository: mockWalletRepo,
      transactionRepository: mockTransactionRepo,
      cacheManager: mockCacheManager,
      walletUseCase: mockUseCase,
      storeId: storeId,
    );
    provider.updateSubscriptionProvider(mockSubProvider);
  });

  group('WalletProvider Optimistic UI Tests', () {
    test(
        'createWallet should generate client-side UUID and insert to local list immediately',
        () async {
      final createCompleter = Completer<void>();
      when(() => mockWalletRepo.getWalletsCount(storeId))
          .thenAnswer((_) async => 1);
      when(() => mockWalletRepo.createWallet(any()))
          .thenAnswer((_) => createCompleter.future);

      // Fetch initial state first so we have the initial list
      await provider.fetchInitialWallets();
      expect(provider.wallets.length, 1);

      // Create wallet (not completed Firestore write yet)
      final createFuture = provider.createWallet(
        phoneNumber: '01111111111',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'u1',
      );

      // Yield control for async setup / permission check / count check
      await Future.delayed(Duration.zero);

      // Verify optimistic mutation: wallet should be in local list
      expect(provider.wallets.length, 2);
      final newWallet =
          provider.wallets.firstWhere((w) => w.walletId != 'w_initial');

      // ID should be a UUID
      expect(
          RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
              .hasMatch(newWallet.walletId),
          isTrue);
      expect(newWallet.balance, 100.0);
      expect(provider.walletMap.containsKey(newWallet.walletId), isTrue);

      // Complete Firestore write
      createCompleter.complete();
      final result = await createFuture;
      expect(result, isTrue);
    });

    test('failed createWallet should trigger rollback to snapshot', () async {
      when(() => mockWalletRepo.getWalletsCount(storeId))
          .thenAnswer((_) async => 1);
      when(() => mockWalletRepo.createWallet(any()))
          .thenThrow(Exception('Firestore write failed'));

      await provider.fetchInitialWallets();
      expect(provider.wallets.length, 1);

      final result = await provider.createWallet(
        phoneNumber: '01111111111',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'u1',
      );

      expect(result, isFalse);
      // Reverted back to initial state (1 wallet)
      expect(provider.wallets.length, 1);
      expect(provider.wallets.first.walletId, 'w_initial');
    });

    test(
        'updateWallet should optimistically update local model and rollback on failure',
        () async {
      final updateCompleter = Completer<void>();
      when(() => mockWalletRepo.updateWallet(any(), any()))
          .thenAnswer((_) => updateCompleter.future);

      await provider.fetchInitialWallets();
      expect(provider.wallets.first.balance, 500.0);

      // Trigger update
      final updateFuture =
          provider.updateWallet('w_initial', {'balance': 600.0});

      // Yield control
      await Future.delayed(Duration.zero);

      // Optimistically updated in local memory
      expect(provider.wallets.first.balance, 600.0);

      // Complete Firestore update
      updateCompleter.complete();
      final result = await updateFuture;
      expect(result, isTrue);
    });

    test('updateWallet rollback on failure', () async {
      when(() => mockWalletRepo.updateWallet(any(), any()))
          .thenThrow(Exception('Update failed'));

      await provider.fetchInitialWallets();
      expect(provider.wallets.first.balance, 500.0);

      final result =
          await provider.updateWallet('w_initial', {'balance': 600.0});

      expect(result, isFalse);
      // Reverted to original balance
      expect(provider.wallets.first.balance, 500.0);
    });

    test(
        'deleteWallet should optimistically remove local model and rollback on failure',
        () async {
      final deleteCompleter = Completer<void>();
      when(() => mockWalletRepo.deleteWallet(any()))
          .thenAnswer((_) => deleteCompleter.future);

      await provider.fetchInitialWallets();
      expect(provider.wallets.length, 1);

      // Trigger delete
      final deleteFuture = provider.deleteWallet('w_initial');

      // Yield control
      await Future.delayed(Duration.zero);

      // Optimistically deleted from local memory
      expect(provider.wallets, isEmpty);

      // Complete delete
      deleteCompleter.complete();
      final result = await deleteFuture;
      expect(result, isTrue);
    });

    test('deleteWallet rollback on failure', () async {
      when(() => mockWalletRepo.deleteWallet(any()))
          .thenThrow(Exception('Delete failed'));

      await provider.fetchInitialWallets();
      expect(provider.wallets.length, 1);

      final result = await provider.deleteWallet('w_initial');

      expect(result, isFalse);
      // Reverted, should be present again
      expect(provider.wallets.length, 1);
      expect(provider.wallets.first.walletId, 'w_initial');
    });

    test('dynamic total active wallets summary count', () async {
      await provider.fetchInitialWallets();
      expect(provider.totalActiveWallets, 1);

      // Stub createWallet to succeed
      when(() => mockWalletRepo.getWalletsCount(storeId))
          .thenAnswer((_) async => 1);
      when(() => mockWalletRepo.createWallet(any())).thenAnswer((_) async {});

      await provider.createWallet(
        phoneNumber: '011',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'u1',
      );

      // Getters should compute dynamically from local list
      expect(provider.totalActiveWallets, 2);
    });

    test(
        'fetchInitialWallets with forceRefresh should preserve pending optimistic wallets',
        () async {
      final createCompleter = Completer<void>();
      when(() => mockWalletRepo.getWalletsCount(storeId))
          .thenAnswer((_) async => 1);
      when(() => mockWalletRepo.createWallet(any()))
          .thenAnswer((_) => createCompleter.future);

      await provider.fetchInitialWallets();
      expect(provider.wallets.length, 1);

      // Create wallet, keeping it pending
      final createFuture = provider.createWallet(
        phoneNumber: '01111111111',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'u1',
      );

      await Future.delayed(Duration.zero);

      // We have 1 pending wallet in provider's local list
      expect(provider.wallets.length, 2);
      final pendingWalletId = provider.wallets
          .firstWhere((w) => w.walletId != 'w_initial')
          .walletId;

      // Mock repository response for fetchInitialWallets
      final serverWallet = WalletModel(
        walletId: 'w_server',
        storeId: storeId,
        phoneNumber: '01222222222',
        walletType: WalletType.instaPay,
        walletStatus: WalletStatus.active,
        balance: 300.0,
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
      when(() => mockWalletRepo.getAllWallets(storeId)).thenAnswer((_) async =>
          PaginatedResult<WalletModel>(
              items: [serverWallet], lastDocument: null));

      // Trigger pull-to-refresh
      await provider.fetchInitialWallets(forceRefresh: true);

      // Verify that the local list now has the fetched server wallet AND the pending wallet!
      expect(provider.wallets.length, 2);
      expect(provider.wallets.any((w) => w.walletId == 'w_server'), isTrue);
      expect(
          provider.wallets.any((w) => w.walletId == pendingWalletId), isTrue);

      // Clean up/Complete pending write
      createCompleter.complete();
      await createFuture;
    });
  });

  group('Wallet Freezing on Limit Change', () {
    late WalletModel w1;
    late WalletModel w2;
    late WalletModel w3;

    setUp(() {
      w1 = WalletModel(
        walletId: 'w1',
        storeId: storeId,
        phoneNumber: '0101',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        receiveLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        stats: WalletStats(),
      );

      w2 = WalletModel(
        walletId: 'w2',
        storeId: storeId,
        phoneNumber: '0102',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        receiveLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        stats: WalletStats(),
      );

      w3 = WalletModel(
        walletId: 'w3',
        storeId: storeId,
        phoneNumber: '0103',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        receiveLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        stats: WalletStats(),
      );
    });

    test(
        'optimistically suspends excess wallets (newest first) and writes to Firestore',
        () async {
      provider.setWalletsForTesting([w1, w2, w3]);

      when(() => mockSubProvider.maxWallets).thenReturn(2);
      when(() =>
              mockWalletRepo.updateWallet('w3', {'walletStatus': 'suspended'}))
          .thenAnswer((_) async => {});

      // Trigger the update
      provider.updateSubscriptionProvider(mockSubProvider);

      // Expect w3 to be suspended immediately (Optimistic UI)
      expect(
          provider.wallets.firstWhere((w) => w.walletId == 'w1').walletStatus,
          WalletStatus.active);
      expect(
          provider.wallets.firstWhere((w) => w.walletId == 'w2').walletStatus,
          WalletStatus.active);
      expect(
          provider.wallets.firstWhere((w) => w.walletId == 'w3').walletStatus,
          WalletStatus.suspended);

      // Wait for background writes
      await Future.delayed(Duration.zero);

      verify(() =>
              mockWalletRepo.updateWallet('w3', {'walletStatus': 'suspended'}))
          .called(1);
    });

    test('rolls back to active status on Firestore write failure', () async {
      provider.setWalletsForTesting([w1, w2, w3]);

      when(() => mockSubProvider.maxWallets).thenReturn(2);
      when(() =>
              mockWalletRepo.updateWallet('w3', {'walletStatus': 'suspended'}))
          .thenThrow(Exception('Firestore write failed'));

      // Trigger update
      provider.updateSubscriptionProvider(mockSubProvider);

      // Should be active again after failure rollback
      await Future.delayed(Duration.zero);
      expect(
          provider.wallets.firstWhere((w) => w.walletId == 'w3').walletStatus,
          WalletStatus.active);
    });
  });
}
