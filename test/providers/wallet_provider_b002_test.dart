import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';

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

    walletProvider = WalletProvider(
      authProvider: mockAuth,
      walletRepository: mockWalletRepo,
      transactionRepository: mockTransactionRepo,
      cacheManager: mockCacheManager,
      walletUseCase: mockUseCase,
      storeId: 'test_store',
    );
  });

  test('Bug B-002: createWallet should return false if subscriptionProvider is null', () async {
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

    // 2. Act: Attempt to create a wallet
    final result = await walletProvider.createWallet(
      phoneNumber: '01012345678',
      walletType: WalletType.vodafoneCash, // ENUM refactor
      walletStatus: WalletStatus.active, // ENUM refactor
      balance: 100.0,
      createdBy: 'user1',
    );

    // 3. Assert: 
    // CURRENT BEHAVIOR (Buggy): It proceeds to try creating in repo because it bypasses limits
    // DESIRED BEHAVIOR (Fixed): It should return false and set an error message
    
    expect(result, isFalse, reason: 'Wallet creation should fail if subscription state is unresolved');
    expect(walletProvider.errorMessage, equals('wallet_error_subscription_unresolved'));
  });

  group('WalletProvider Error Transparency (Phase 5)', () {
    test('createWallet should propagate ServerException from repository', () async {
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

      // Should currently FAIL this test because it catches internally and returns false
      expect(() => walletProvider.createWallet(
        phoneNumber: '01012345678',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100.0,
        createdBy: 'user1',
      ), throwsA(isA<Exception>()));
    });
  });
}
