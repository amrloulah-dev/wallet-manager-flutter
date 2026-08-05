import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';

import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/data/services/wallet_cache_manager.dart';
import 'package:walletmanager/domain/usecases/wallet_usecase.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockWalletRepository extends Mock implements WalletRepository {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

class MockWalletCacheManager extends Mock implements WalletCacheManager {}

class MockWalletUseCase extends Mock implements WalletUseCase {}

class FakeWalletModel extends Fake implements WalletModel {}

void main() {
  late MockAuthProvider mockAuth;
  late MockWalletRepository mockWalletRepo;
  late MockTransactionRepository mockTransactionRepo;
  late MockWalletCacheManager mockCacheManager;
  late MockWalletUseCase mockUseCase;
  late WalletProvider walletProvider;

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

    // Stub cache manager
    when(() => mockCacheManager.cacheWallets(any())).thenAnswer((_) async {});

    // Stub UseCase
    final mockUser = UserModel(
      userId: 'user1',
      storeId: 'test_store',
      role: UserRole.owner, // ENUM refactor
      fullName: 'Test Owner',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    when(() => mockUseCase.validatePermission(any()))
        .thenAnswer((_) async => mockUser);
    when(() => mockUseCase.calculateFrozenWallets(
          wallets: any(named: 'wallets'),
          subscriptionProvider: any(named: 'subscriptionProvider'),
          storeId: any(named: 'storeId'),
        )).thenReturn(<String>{});

    walletProvider = WalletProvider(
      authProvider: mockAuth,
      walletRepository: mockWalletRepo,
      transactionRepository: mockTransactionRepo,
      cacheManager: mockCacheManager,
      walletUseCase: mockUseCase,
      storeId: 'test_store',
    );
  });

  test(
      'Bug B-002: createWallet should return false if subscriptionProvider is null',
      () async {
    // 1. Setup: Auth indicates a user is logged in
    final mockUser = UserModel(
      userId: 'user1',
      storeId: 'test_store',
      role: UserRole.owner, // ENUM refactor
      fullName: 'Test Owner',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
    );
    when(() => mockAuth.ensureUserLoaded()).thenAnswer((_) async => mockUser);
    when(() => mockAuth.currentUserId).thenReturn('user1');
    // NOTE: subscriptionProvider is NOT provided, so it is null in the WalletProvider

    // 2. Act & Assert: Attempt to create a wallet
    // DESIRED BEHAVIOR (Requirement 1.5.2): It returns false because it caught the error and showed Toast
    final success = await walletProvider.createWallet(
      phoneNumber: '01012345678',
      walletType: WalletType.vodafoneCash,
      walletStatus: WalletStatus.active,
      balance: 100.0,
      createdBy: 'user1',
    );

    expect(success, isFalse);
    expect(walletProvider.errorMessage,
        equals('wallet_error_subscription_unresolved'));
  });

  group('WalletProvider Error Transparency (Phase 5)', () {
    test('createWallet should return false and set error if repository throws',
        () async {
      final mockUser = UserModel(
        userId: 'user1',
        storeId: 'test_store',
        role: UserRole.owner,
        fullName: 'Test Owner',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      when(() => mockAuth.ensureUserLoaded()).thenAnswer((_) async => mockUser);
      when(() => mockAuth.currentUserId).thenReturn('user1');

      // Stub repo to throw
      when(() => mockWalletRepo.createWallet(any()))
          .thenThrow(Exception('Firestore crash'));

      // 1.5.2 compliance: Catch internal, return false
      final success = await walletProvider.createWallet(
        phoneNumber: '01012345678',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'user1',
      );

      expect(success, isFalse);
      expect(walletProvider.hasError, isTrue);
    });
  });

  group('WalletProvider resetLimitsForWallets Employee Guard', () {
    test(
        'fetchInitialWallets does NOT call resetLimitsForWallets when user is an employee',
        () async {
      when(() => mockAuth.isOwner).thenReturn(false);

      final defaultLimits =
          WalletLimits(dailyLimit: 10000, monthlyLimit: 50000);
      final defaultStats = WalletStats();

      final legacyWalletNeedingReset = WalletModel(
        walletId: 'w1',
        storeId: 'test_store',
        phoneNumber: '01012345678',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 500.0,
        createdBy: 'u1',
        sendLimits: defaultLimits,
        receiveLimits: defaultLimits,
        stats: defaultStats,
        lastDailyReset: DateTime.now().subtract(const Duration(days: 2)),
      );

      when(() => mockWalletRepo.getAllWallets('test_store')).thenAnswer(
        (_) async => PaginatedResult<WalletModel>(
          items: [legacyWalletNeedingReset],
          lastDocument: null,
        ),
      );

      await walletProvider.fetchInitialWallets(forceRefresh: true);

      verifyNever(() => mockWalletRepo.resetLimitsForWallets(any()));
    });

    test(
        'fetchInitialWallets calls resetLimitsForWallets when user is an owner',
        () async {
      when(() => mockAuth.isOwner).thenReturn(true);

      final defaultLimits =
          WalletLimits(dailyLimit: 10000, monthlyLimit: 50000);
      final defaultStats = WalletStats();

      final legacyWalletNeedingReset = WalletModel(
        walletId: 'w1',
        storeId: 'test_store',
        phoneNumber: '01012345678',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 500.0,
        createdBy: 'u1',
        sendLimits: defaultLimits,
        receiveLimits: defaultLimits,
        stats: defaultStats,
        lastDailyReset: DateTime.now().subtract(const Duration(days: 2)),
      );

      when(() => mockWalletRepo.getAllWallets('test_store')).thenAnswer(
        (_) async => PaginatedResult<WalletModel>(
          items: [legacyWalletNeedingReset],
          lastDocument: null,
        ),
      );
      when(() => mockWalletRepo.resetLimitsForWallets(any()))
          .thenAnswer((_) async {});

      await walletProvider.fetchInitialWallets(forceRefresh: true);

      verify(() => mockWalletRepo.resetLimitsForWallets(any())).called(1);
    });
  });
}
