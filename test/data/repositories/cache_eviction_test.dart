import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';

class MockFirebaseService extends Mock implements FirebaseService {}
class MockStatsRepository extends Mock implements StatsRepository {}
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}

class FakeDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {
  @override
  bool get exists => true;
  @override
  Map<String, dynamic> data() => {'storeId': 'store1', 'isActive': true};
}

void main() {
  late CacheManager cacheManager;
  late TransactionRepository transactionRepository;
  late DebtRepository debtRepository;
  late WalletRepository walletRepository;
  late MockFirebaseService mockFirebaseService;
  late MockStatsRepository mockStatsRepository;
  late MockFirestore mockFirestore;

  setUp(() {
    cacheManager = CacheManager();
    cacheManager.clearAll();
    
    mockFirebaseService = MockFirebaseService();
    mockStatsRepository = MockStatsRepository();
    mockFirestore = MockFirestore();
    
    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);

    transactionRepository = TransactionRepository(
      firebaseService: mockFirebaseService,
      cacheManager: cacheManager,
      statsRepository: mockStatsRepository,
    );

    debtRepository = DebtRepository(
      firebaseService: mockFirebaseService,
      cacheManager: cacheManager,
    );

    walletRepository = WalletRepository(
      firebaseService: mockFirebaseService,
      cacheManager: cacheManager,
      statsRepository: mockStatsRepository,
    );

    registerFallbackValue(TransactionModel(
      transactionId: 'any',
      storeId: 'any',
      walletId: 'any',
      transactionType: TransactionType.debit,
      amount: 0,
      createdBy: 'any',
    ));
    registerFallbackValue(MockDocumentReference());
    registerFallbackValue(<String, dynamic>{});
  });

  group('Stale Cache Eviction (TDD - Phase 3)', () {
    test('TransactionRepository should clear ALL transaction pages on update', () async {
      cacheManager.set('transactions_page_0_store1', []);
      cacheManager.set('transactions_page_1_store1', []);
      
      expect(cacheManager.get('transactions_page_0_store1'), isNotNull);
      expect(cacheManager.get('transactions_page_1_store1'), isNotNull);

      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDoc);
      when(() => mockDoc.update(any())).thenAnswer((_) async => null);
      
      await transactionRepository.updateTransaction('t1', {'amount': 200});

      expect(cacheManager.get('transactions_page_0_store1'), isNull);
      expect(cacheManager.get('transactions_page_1_store1'), isNull);
    });

    test('DebtRepository should clear ALL debt pages on update', () async {
      cacheManager.set('debts_page_0_store1', []);
      cacheManager.set('debts_page_1_store1', []);
      
      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDoc);
      when(() => mockDoc.get()).thenAnswer((_) async => FakeDocumentSnapshot());
      when(() => mockDoc.update(any())).thenAnswer((_) async => null);

      await debtRepository.updateDebt('d1', {'amount': 500});

      expect(cacheManager.get('debts_page_0_store1'), isNull);
      expect(cacheManager.get('debts_page_1_store1'), isNull);
    });

    test('WalletRepository should clear ALL wallet pages on create', () async {
      cacheManager.set('wallets_page_0_store1', []);
      cacheManager.set('wallets_page_1_store1', []);

      final mockCollection = MockCollectionReference();
      final mockDoc = MockDocumentReference();

      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDoc);
      when(() => mockDoc.set(any())).thenAnswer((_) async => null);
      
      when(() => mockStatsRepository.updateStatsOnWalletChange(
        any(),
        countChange: any(named: 'countChange'),
        activeCountChange: any(named: 'activeCountChange'),
        balanceChange: any(named: 'balanceChange'),
      )).thenAnswer((_) async => null);

      final wallet = WalletModel(
        walletId: 'w1',
        storeId: 's1',
        phoneNumber: '012',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100,
        createdBy: 'user1',
        sendLimits: WalletLimits(dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        receiveLimits: WalletLimits(dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        stats: WalletStats(totalTransactions: 0, totalCommission: 0, totalSentAmount: 0, totalReceivedAmount: 0),
      );

      await walletRepository.createWallet(wallet);

      expect(cacheManager.get('wallets_page_0_store1'), isNull);
      expect(cacheManager.get('wallets_page_1_store1'), isNull);
    });
  });
}

