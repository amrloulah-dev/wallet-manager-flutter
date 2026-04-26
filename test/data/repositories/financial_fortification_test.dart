import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}
class MockCacheManager extends Mock implements CacheManager {}
class MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late StatsRepository statsRepository;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    statsRepository = StatsRepository(firestore: fakeFirestore);
    
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);
  });

  group('Financial Fortification Guards', () {
    test('DebtRepository.processPayment should throw DomainException for negative amount', () async {
      final repository = DebtRepository(firebaseService: mockFirebaseService);
      expect(() => repository.processPayment('debt1', -50.0, 'user1'),
          throwsA(isA<DomainException>()));
    });

    test('DebtRepository.addPartialDebt should throw DomainException for negative amount', () async {
      final repository = DebtRepository(firebaseService: mockFirebaseService);
      expect(() => repository.addPartialDebt('debt1', -50.0, 'user1'),
          throwsA(isA<DomainException>()));
    });

    test('TransactionRepository.createDeposit should throw DomainException for negative amount', () async {
      final repository = TransactionRepository(
        firebaseService: mockFirebaseService,
        statsRepository: statsRepository,
      );
      expect(() => repository.createDeposit(
        transactionId: 'tx1',
        storeId: 'store1',
        walletId: 'wallet1',
        amount: -100.0,
        createdBy: 'user1',
      ), throwsA(isA<DomainException>()));
    });

    test('WalletRepository.updateWalletBalance should throw DomainException for negative amount', () async {
      final repository = WalletRepository(
        firebaseService: mockFirebaseService,
        statsRepository: statsRepository,
      );
      expect(() => repository.updateWalletBalance('wallet1', -100.0),
          throwsA(isA<DomainException>()));
    });

    test('StatsRepository.incrementOpenDebtStats should throw DomainException for negative amount', () async {
      final repository = StatsRepository(firestore: fakeFirestore);
      expect(() => repository.incrementOpenDebtStats('store1', -100.0),
          throwsA(isA<DomainException>()));
    });
  });
}
