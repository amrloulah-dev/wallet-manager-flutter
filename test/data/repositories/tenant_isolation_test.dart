import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

Map<String, dynamic> _createValidWalletData(String storeId) {
  final now = Timestamp.now();
  return {
    'storeId': storeId,
    'phoneNumber': '0123456789',
    'walletType': 'vodafone_cash',
    'balance': 100.0,
    'isActive': true,
    'createdAt': now,
    'lastDailyReset': now,
    'lastMonthlyReset': now,
    'sendLimits': {
      'dailyLimit': 1000.0,
      'dailyUsed': 0.0,
      'monthlyLimit': 5000.0,
      'monthlyUsed': 0.0,
    },
    'receiveLimits': {
      'dailyLimit': 1000.0,
      'dailyUsed': 0.0,
      'monthlyLimit': 5000.0,
      'monthlyUsed': 0.0,
    },
  };
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late WalletRepository walletRepo;
  late TransactionRepository transactionRepo;
  late DebtRepository debtRepo;
  late UserRepository userRepo;

  const ownerStoreId = 'owner_store';
  const otherStoreId = 'other_store';

  setUp(() {
    AppErrorHandler.isTestMode = true;
    final sl = GetIt.instance;
    sl.reset();
    
    fakeFirestore = FakeFirebaseFirestore();
    
    // Mock FirebaseService to return our fake firestore
    final mockFirebaseService = FirebaseService();
    mockFirebaseService.initializeForTest(fakeFirestore);
    sl.registerSingleton<FirebaseService>(mockFirebaseService);
    
    sl.registerSingleton<StatsRepository>(StatsRepository(firestore: fakeFirestore));
    sl.registerSingleton<CacheManager>(CacheManager());

    walletRepo = WalletRepository(firestore: fakeFirestore);
    transactionRepo = TransactionRepository(firestore: fakeFirestore);
    debtRepo = DebtRepository(firestore: fakeFirestore);
    userRepo = UserRepository(firebaseService: mockFirebaseService);
  });

  group('Tenant Isolation Tests', () {
    test('WalletRepository.getWalletById should throw PermissionDeniedException if storeId mismatches', () async {
      final walletId = 'w1';
      await fakeFirestore.collection('wallets').doc(walletId).set(_createValidWalletData(otherStoreId));

      expect(
        () => walletRepo.getWalletById(walletId, expectedStoreId: ownerStoreId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('TransactionRepository.getTransactionById should throw PermissionDeniedException if storeId mismatches', () async {
      final txId = 't1';
      final now = Timestamp.now();
      await fakeFirestore.collection('transactions').doc(txId).set({
        'storeId': otherStoreId,
        'walletId': 'w1',
        'amount': 50.0,
        'transactionType': 'send',
        'paymentStatus': 'paid',
        'transactionDate': now,
        'createdAt': now,
        'createdBy': 'System',
        'isDeleted': false,
      });

      expect(
        () => transactionRepo.getTransactionById(txId, expectedStoreId: ownerStoreId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('DebtRepository.getDebtById should throw PermissionDeniedException if storeId mismatches', () async {
      final debtId = 'd1';
      final now = Timestamp.now();
      await fakeFirestore.collection('debts').doc(debtId).set({
        'storeId': otherStoreId,
        'customerName': 'Customer',
        'amountDue': 200.0,
        'totalAmount': 200.0,
        'debtStatus': 'open',
        'createdAt': now,
        'debtDate': now,
      });

      expect(
        () => debtRepo.getDebtById(debtId, expectedStoreId: ownerStoreId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('WalletRepository.updateWallet should fail assertion if storeId is passed', () async {
      expect(
        () => walletRepo.updateWallet('w1', {'storeId': 'new_store'}),
        throwsA(isA<AssertionError>()),
      );
    });

    test('WalletRepository.watchWallet should emit PermissionDeniedException if storeId mismatches', () async {
      final walletId = 'w1';
      await fakeFirestore.collection('wallets').doc(walletId).set(_createValidWalletData(otherStoreId));

      final stream = walletRepo.watchWallet(walletId, expectedStoreId: ownerStoreId);
      
      expect(stream, emitsError(isA<PermissionDeniedException>()));
    });

    test('UserRepository.getUserById should throw PermissionDeniedException if storeId mismatches', () async {
      final userId = 'u1';
      final now = Timestamp.now();
      await fakeFirestore.collection('users').doc(userId).set({
        'storeId': otherStoreId,
        'role': 'employee',
        'fullName': 'Employee Name',
        'createdAt': now,
        'lastLogin': now,
      });

      expect(
        () => userRepo.getUserById(userId, expectedStoreId: ownerStoreId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('UserRepository.hardDeleteUser should throw PermissionDeniedException if caller is not owner', () async {
      final userId = 'u1';
      final callerId = 'c1';
      final now = Timestamp.now();
      
      // Setup caller as employee
      await fakeFirestore.collection('users').doc(callerId).set({
        'storeId': ownerStoreId,
        'role': 'employee',
        'fullName': 'Employee Caller',
        'createdAt': now,
        'lastLogin': now,
      });

      expect(
        () => userRepo.hardDeleteUser(userId, callerUserId: callerId),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
