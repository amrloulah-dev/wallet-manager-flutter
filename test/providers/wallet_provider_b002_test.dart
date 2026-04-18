import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockWalletRepository extends Mock implements WalletRepository {}
class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockAuthProvider mockAuth;
  late MockWalletRepository mockWalletRepo;
  late MockTransactionRepository mockTransactionRepo;
  late WalletProvider walletProvider;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    mockAuth = MockAuthProvider();
    mockWalletRepo = MockWalletRepository();
    mockTransactionRepo = MockTransactionRepository();

    walletProvider = WalletProvider(
      authProvider: mockAuth,
      walletRepository: mockWalletRepo,
      transactionRepository: mockTransactionRepo,
      storeId: 'test_store',
    );
  });

  test('Bug B-002: createWallet should return false if subscriptionProvider is null', () async {
    // 1. Setup: Auth indicates a user is logged in
    final mockUser = UserModel(
      userId: 'user1',
      storeId: 'test_store',
      role: 'owner',
      fullName: 'Test Owner',
      createdAt: Timestamp.now(),
      lastLogin: Timestamp.now(),
    );
    when(() => mockAuth.ensureUserLoaded()).thenAnswer((_) async => mockUser);
    when(() => mockAuth.currentUserId).thenReturn('user1');
    // NOTE: subscriptionProvider is NOT provided, so it is null in the WalletProvider

    // 2. Act: Attempt to create a wallet
    final result = await walletProvider.createWallet(
      phoneNumber: '01012345678',
      walletType: 'vodafone_cash',
      walletStatus: 'new',
      balance: 100.0,
      createdBy: 'user1',
    );

    // 3. Assert: 
    // CURRENT BEHAVIOR (Buggy): It proceeds to try creating in repo because it bypasses limits
    // DESIRED BEHAVIOR (Fixed): It should return false and set an error message
    
    expect(result, isFalse, reason: 'Wallet creation should fail if subscription state is unresolved');
    expect(walletProvider.errorMessage, contains('تعذر التحقق من حالة الاشتراك'));
  });
}
