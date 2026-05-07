import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/services/transaction_validator_service.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockTransactionModel extends Mock implements TransactionModel {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCacheManager extends Mock implements CacheManager {}

class MockStatsRepository extends Mock implements StatsRepository {}

class MockTransaction extends Mock implements Transaction {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class FakeDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {}

class FakeTransaction extends Fake implements Transaction {}

class FakeSetOptions extends Fake implements SetOptions {}

void main() {
  late TransactionValidatorService service;
  late MockFirebaseFirestore mockFirestore;
  late MockTransactionModel mockTxModel;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late MockStatsRepository mockStatsRepository;
  late MockTransaction mockTx;
  late MockDocumentSnapshot mockWalletSnap;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockWalletRef;

  final nowTs = Timestamp.now();

  setUpAll(() {
    AppErrorHandler.isTestMode = true;
    registerFallbackValue(FakeDocumentReference());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(FakeSetOptions());
    registerFallbackValue(MockTransactionModel());
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    service = TransactionValidatorService(firestore: mockFirestore);
    mockTxModel = MockTransactionModel();

    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    mockStatsRepository = MockStatsRepository();
    mockTx = MockTransaction();
    mockWalletSnap = MockDocumentSnapshot();
    mockCollection = MockCollectionReference();
    mockWalletRef = MockDocumentReference();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);

    // Transaction Model setup
    when(() => mockTxModel.transactionId).thenReturn('tx123');
    when(() => mockTxModel.walletId).thenReturn('w123');
    when(() => mockTxModel.storeId).thenReturn('s123');
    when(() => mockTxModel.amount).thenReturn(100.0);
    when(() => mockTxModel.commission).thenReturn(0.0);
    when(() => mockTxModel.serviceFee).thenReturn(0.0);
    when(() => mockTxModel.transactionType).thenReturn(TransactionType.debit);
    when(() => mockTxModel.isSend).thenReturn(true);
    when(() => mockTxModel.isDeposit).thenReturn(false);
    when(() => mockTxModel.isReceive).thenReturn(false);
    when(() => mockTxModel.toFirestore()).thenReturn({});

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockFirestore.doc(any())).thenReturn(mockWalletRef);
    when(() => mockCollection.doc(any())).thenReturn(mockWalletRef);
    when(() => mockWalletRef.collection(any())).thenReturn(mockCollection);
    when(() => mockWalletRef.get()).thenAnswer((_) async => mockWalletSnap);

    when(() => mockFirestore.runTransaction<void>(any()))
        .thenAnswer((invocation) async {
      final callback = invocation.positionalArguments[0] as Function;
      await callback(mockTx);
    });

    when(() => mockFirestore.runTransaction<dynamic>(any()))
        .thenAnswer((invocation) async {
      final callback = invocation.positionalArguments[0] as Function;
      return await callback(mockTx);
    });

    when(() => mockFirestore.runTransaction<Null>(any()))
        .thenAnswer((invocation) async {
      final callback = invocation.positionalArguments[0] as Function;
      await callback(mockTx);
    });

    when(() => mockTx.get<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => mockWalletSnap);

    when(() => mockTx.set<Map<String, dynamic>>(any(), any()))
        .thenReturn(mockTx);

    when(() => mockTx.set<Map<String, dynamic>>(any(), any(), any()))
        .thenReturn(mockTx);

    when(() => mockTx.update(any(), any())).thenReturn(mockTx);

    // Also add stubs for Object? just in case for WalletRepository
    when(() => mockTx.get<Object?>(any()))
        .thenAnswer((_) async => mockWalletSnap);
    when(() => mockTx.set<Object?>(any(), any())).thenReturn(mockTx);
    when(() => mockTx.update(any(), any())).thenReturn(mockTx);

    when(() => mockWalletSnap.exists).thenReturn(true);
    when(() => mockWalletSnap.id).thenReturn('w123');
    when(() => mockWalletSnap.reference).thenReturn(mockWalletRef);

    when(() => mockCacheManager.get<WalletModel>(any())).thenReturn(null);

    // Patterns for creditWallet and debitWallet
    when(() => mockStatsRepository.updateStatsOnWalletChange(
          any(),
          countChange: any(named: 'countChange'),
          activeCountChange: any(named: 'activeCountChange'),
          balanceChange: any(named: 'balanceChange'),
          firestoreTransaction: any(named: 'firestoreTransaction'),
        )).thenAnswer((_) async => {});
  });

  Map<String, dynamic> createValidWalletData({required double balance}) {
    return {
      'walletId': 'w123',
      'storeId': 's123',
      'phoneNumber': '1234567890',
      'walletType': WalletType.vodafoneCash.name,
      'walletStatus': 'active',
      'balance': balance,
      'isActive': true,
      'createdBy': 'user123',
      FirebaseConstants.createdAt: nowTs,
      FirebaseConstants.lastDailyReset: nowTs,
      FirebaseConstants.lastMonthlyReset: nowTs,
      FirebaseConstants.sendLimits: {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 10000.0,
        'monthlyUsed': 0.0,
      },
      FirebaseConstants.receiveLimits: {
        'dailyLimit': 1000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 10000.0,
        'monthlyUsed': 0.0,
      },
      FirebaseConstants.stats: {
        'totalTransactions': 0,
        'totalSentAmount': 0.0,
        'totalReceivedAmount': 0.0,
        'totalCommission': 0.0,
      },
    };
  }

  group('Balance Precision (Step 1.2)', () {
    test(
        'should allow transaction when balance is slightly less than totalDeduction but within epsilon (Floating Point Ghost)',
        () async {
      when(() => mockWalletSnap.data())
          .thenReturn(createValidWalletData(balance: 99.99));

      await service.validateAndSave(mockTxModel);
    });

    test(
        'should throw ValidationException when balance is clearly insufficient (Negative Balance Prevention)',
        () async {
      when(() => mockWalletSnap.data())
          .thenReturn(createValidWalletData(balance: 50.0));

      expect(
        () => service.validateAndSave(mockTxModel),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  group('WalletRepository (Step 1.2)', () {
    test(
        'debitWallet should use epsilon tolerance (99.99 balance allows 100.0 debit)',
        () async {
      final repo = WalletRepository(
        firebaseService: mockFirebaseService,
        cacheManager: mockCacheManager,
        statsRepository: mockStatsRepository,
      );

      when(() => mockWalletSnap.data())
          .thenReturn(createValidWalletData(balance: 99.99));

      await repo.debitWallet('w123', 100.0);
    });

    test(
        'debitWallet should throw DomainException on clearly insufficient balance',
        () async {
      final repo = WalletRepository(
        firebaseService: mockFirebaseService,
        cacheManager: mockCacheManager,
        statsRepository: mockStatsRepository,
      );

      when(() => mockWalletSnap.data())
          .thenReturn(createValidWalletData(balance: 50.0));

      expect(
        () => repo.debitWallet('w123', 100.0),
        throwsA(isA<DomainException>()),
      );
    });
  });
}
