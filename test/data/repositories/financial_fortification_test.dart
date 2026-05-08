import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCacheManager extends Mock implements CacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late StatsRepository statsRepository;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    statsRepository = StatsRepository(firestore: fakeFirestore);

    sl.allowReassignment = true;
    sl.registerSingleton<CacheManager>(mockCacheManager);

    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);
  });

  group('Financial Fortification Guards', () {
    test(
        'DebtRepository.processPayment should throw DomainException for negative amount',
        () async {
      final repository = DebtRepository(firebaseService: mockFirebaseService);
      expect(() => repository.processPayment('debt1', -50.0, 'user1'),
          throwsA(isA<DomainException>()));
    });

    test(
        'DebtRepository.addPartialDebt should throw DomainException for negative amount',
        () async {
      final repository = DebtRepository(firebaseService: mockFirebaseService);
      expect(() => repository.addPartialDebt('debt1', -50.0, 'user1'),
          throwsA(isA<DomainException>()));
    });

    test(
        'TransactionRepository.createDeposit should throw DomainException for negative amount',
        () async {
      final repository = TransactionRepository(
        firebaseService: mockFirebaseService,
        statsRepository: statsRepository,
      );
      expect(
          () => repository.createDeposit(
                transactionId: 'tx1',
                storeId: 'store1',
                walletId: 'wallet1',
                amount: -100.0,
                createdBy: 'user1',
              ),
          throwsA(isA<DomainException>()));
    });

    test(
        'DebtRepository.processPayment should throw InvalidAmountException for overpayment',
        () async {
      final repository = DebtRepository(firebaseService: mockFirebaseService);

      // Setup: Create a debt with amountDue = 100
      final debtId = 'debt100';
      await fakeFirestore.collection('debts').doc(debtId).set({
        'debtId': debtId,
        'storeId': 'store1',
        'amountDue': 100.0,
        'totalAmount': 100.0,
        'debtStatus': DebtStatus.open.name,
        'debtType': 'store_sale',
        'customerName': 'Test',
        'customerPhone': '010',
        'createdBy': 'user1',
        'createdAt': Timestamp.now(),
        'debtDate': Timestamp.now(),
      });

      expect(() => repository.processPayment(debtId, 150.0, 'user1'),
          throwsA(isA<InvalidAmountException>()));
    });
  });
}
