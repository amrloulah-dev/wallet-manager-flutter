import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCacheManager extends Mock implements CacheManager {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockWriteBatch extends Mock implements WriteBatch {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(MockDocumentReference());
  });

  late WalletRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late StatsRepository statsRepository;

  const storeId = 'test_store';
  const walletId = 'test_wallet';

  setUp(() {
    AppErrorHandler.isTestMode = true;
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    statsRepository = StatsRepository(firestore: fakeFirestore);

    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);
    when(() => mockCacheManager.clearWhere(any())).thenAnswer((_) async {});
    when(() => mockCacheManager.clear(any())).thenAnswer((_) async {});

    repository = WalletRepository(
      firebaseService: mockFirebaseService,
      cacheManager: mockCacheManager,
      statsRepository: statsRepository,
    );
  });

  group('WalletRepository (FakeFirestore Integration)', () {
    test('creditWallet should increment balance and update stats atomically',
        () async {
      // Setup initial state
      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': 100.0,
        'isActive': true,
        'phoneNumber': '123',
        'walletType': 'vodafoneCash',
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'sendLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 5000.0,
          'monthlyUsed': 0.0
        },
        'receiveLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 5000.0,
          'monthlyUsed': 0.0
        },
      });

      final statsPath = FirebaseConstants.statsSummaryPath(storeId);
      await fakeFirestore.doc(statsPath).set({
        'totalBalance': 100.0,
      });

      // Execute
      await repository.creditWallet(walletId, 50.0);

      // Verify
      final walletSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .get();
      expect(walletSnap.data()?['balance'], 150.0);

      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['totalBalance'], 150.0);
    });

    test('debitWallet should decrement balance and update stats atomically',
        () async {
      // Setup initial state
      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': 200.0,
        'isActive': true,
        'phoneNumber': '123',
        'walletType': 'vodafoneCash',
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'sendLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 5000.0,
          'monthlyUsed': 0.0
        },
        'receiveLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 5000.0,
          'monthlyUsed': 0.0
        },
      });

      final statsPath = FirebaseConstants.statsSummaryPath(storeId);
      await fakeFirestore.doc(statsPath).set({
        'totalBalance': 200.0,
      });

      // Execute
      await repository.debitWallet(walletId, 80.0);

      // Verify
      final walletSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .get();
      expect(walletSnap.data()?['balance'], 120.0);

      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['totalBalance'], 120.0);
    });
  });

  group('WalletRepository.createWallet with mock WriteBatch', () {
    late MockFirebaseFirestore mockFirestore;
    late MockStatsRepository mockStatsRepo;
    late MockCollectionReference mockCollectionRef;
    late MockDocumentReference mockDocRef;
    late MockWriteBatch mockBatch;
    late WalletRepository mockRepository;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockStatsRepo = MockStatsRepository();
      mockCollectionRef = MockCollectionReference();
      mockDocRef = MockDocumentReference();
      mockBatch = MockWriteBatch();

      when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
      when(() => mockFirestore.collection(any())).thenReturn(mockCollectionRef);
      when(() => mockCollectionRef.doc(any())).thenReturn(mockDocRef);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);

      when(() => mockBatch.commit()).thenAnswer((_) async {});
      when(() => mockBatch.set<Object?>(any(), any(), any())).thenReturn(null);
      when(() => mockBatch.set<Object?>(any(), any())).thenReturn(null);

      when(() => mockStatsRepo.updateStatsOnWalletChange(
            any(),
            countChange: any(named: 'countChange'),
            activeCountChange: any(named: 'activeCountChange'),
            balanceChange: any(named: 'balanceChange'),
            batch: any(named: 'batch'),
            firestoreTransaction: any(named: 'firestoreTransaction'),
          )).thenAnswer((_) async {});

      mockRepository = WalletRepository(
        firebaseService: mockFirebaseService,
        cacheManager: mockCacheManager,
        statsRepository: mockStatsRepo,
      );
    });

    test('should use WriteBatch to create wallet and update stats', () async {
      final wallet = WalletModel(
        walletId: walletId,
        storeId: storeId,
        phoneNumber: '123',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 150.0,
        isActive: true,
        createdBy: 'user1',
        sendLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        receiveLimits: WalletLimits(
            dailyLimit: 1000, dailyUsed: 0, monthlyLimit: 5000, monthlyUsed: 0),
        stats: WalletStats(
            totalTransactions: 0,
            totalCommission: 0,
            totalSentAmount: 0,
            totalReceivedAmount: 0),
        createdAt: DateTime.now(),
        lastDailyReset: DateTime.now(),
        lastMonthlyReset: DateTime.now(),
      );

      await mockRepository.createWallet(wallet);

      verify(() => mockFirestore.batch()).called(1);
      verify(() => mockBatch.set<Object?>(mockDocRef, wallet.toFirestore()))
          .called(1);
      verify(() => mockStatsRepo.updateStatsOnWalletChange(
            storeId,
            countChange: 1,
            activeCountChange: 1,
            balanceChange: 150.0,
            batch: mockBatch,
          )).called(1);
      verify(() => mockBatch.commit()).called(1);
      verify(() => mockCacheManager.clearWhere(any())).called(1);
    });
  });

  group('resetLimitsForWallets payload safety', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollectionRef;
    late MockDocumentReference mockDocRef;
    late MockWriteBatch mockBatch;
    late WalletRepository mockRepository;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollectionRef = MockCollectionReference();
      mockDocRef = MockDocumentReference();
      mockBatch = MockWriteBatch();

      when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
      when(() => mockFirestore.collection(any())).thenReturn(mockCollectionRef);
      when(() => mockCollectionRef.doc(any())).thenReturn(mockDocRef);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);

      when(() => mockBatch.commit()).thenAnswer((_) async {});
      when(() => mockBatch.update(any(), captureAny())).thenReturn(null);

      mockRepository = WalletRepository(
        firebaseService: mockFirebaseService,
        cacheManager: mockCacheManager,
        statsRepository: MockStatsRepository(),
      );
    });

    test('daily reset payload uses dot-notation and does not overwrite limit caps or walletStatus', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 2));
      final today = DateTime.now();
      final wallet = WalletModel(
        walletId: 'w_legacy',
        storeId: 's1',
        phoneNumber: '010',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.inactive,
        balance: 500.0,
        isActive: true,
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 60000, dailyUsed: 500, monthlyLimit: 200000, monthlyUsed: 1000),
        receiveLimits: WalletLimits(
            dailyLimit: 60000, dailyUsed: 300, monthlyLimit: 200000, monthlyUsed: 1000),
        stats: WalletStats(),
        lastDailyReset: oldDate,
        lastMonthlyReset: today, // Only daily reset needed
      );

      await mockRepository.resetLimitsForWallets([wallet]);

      final captured = verify(() => mockBatch.update(mockDocRef, captureAny())).captured;
      expect(captured.length, equals(1));
      final Map<String, dynamic> payload = captured.single;

      expect(payload.containsKey('sendLimits.dailyUsed'), isTrue);
      expect(payload['sendLimits.dailyUsed'], equals(0.0));
      expect(payload.containsKey('receiveLimits.dailyUsed'), isTrue);
      expect(payload['receiveLimits.dailyUsed'], equals(0.0));
      expect(payload.containsKey(FirebaseConstants.lastDailyReset), isTrue);

      // Verify NO full-doc or cap overwrites
      expect(payload.containsKey('dailyLimit'), isFalse);
      expect(payload.containsKey('monthlyLimit'), isFalse);
      expect(payload.containsKey('walletStatus'), isFalse);
      expect(payload.containsKey('sendLimits'), isFalse);
      expect(payload.containsKey('receiveLimits'), isFalse);
      expect(payload.containsKey('sendLimits.dailyLimit'), isFalse);
      expect(payload.containsKey('sendLimits.monthlyLimit'), isFalse);
    });

    test('monthly reset payload uses dot-notation and touches only monthly counters and reset timestamp', () async {
      final today = DateTime.now();
      final oldMonth = DateTime.now().subtract(const Duration(days: 40));
      final wallet = WalletModel(
        walletId: 'w_legacy',
        storeId: 's1',
        phoneNumber: '010',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.inactive,
        balance: 500.0,
        isActive: true,
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 60000, dailyUsed: 500, monthlyLimit: 200000, monthlyUsed: 1000),
        receiveLimits: WalletLimits(
            dailyLimit: 60000, dailyUsed: 300, monthlyLimit: 200000, monthlyUsed: 1000),
        stats: WalletStats(),
        lastDailyReset: today,
        lastMonthlyReset: oldMonth, // Only monthly reset needed
      );

      await mockRepository.resetLimitsForWallets([wallet]);

      final captured = verify(() => mockBatch.update(mockDocRef, captureAny())).captured;
      expect(captured.length, equals(1));
      final Map<String, dynamic> payload = captured.single;

      expect(payload.containsKey('sendLimits.monthlyUsed'), isTrue);
      expect(payload['sendLimits.monthlyUsed'], equals(0.0));
      expect(payload.containsKey('receiveLimits.monthlyUsed'), isTrue);
      expect(payload['receiveLimits.monthlyUsed'], equals(0.0));
      expect(payload.containsKey(FirebaseConstants.lastMonthlyReset), isTrue);

      expect(payload.containsKey('sendLimits.dailyUsed'), isFalse);
      expect(payload.containsKey('walletStatus'), isFalse);
    });

    test('combined daily and monthly reset payload is strictly pinpoint', () async {
      final wallet = WalletModel(
        walletId: 'w_null_ts',
        storeId: 's1',
        phoneNumber: '010',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.inactive,
        balance: 500.0,
        isActive: true,
        createdBy: 'u1',
        sendLimits: WalletLimits(
            dailyLimit: 60000, dailyUsed: 500, monthlyLimit: 200000, monthlyUsed: 1000),
        receiveLimits: WalletLimits(
            dailyLimit: 60000, dailyUsed: 300, monthlyLimit: 200000, monthlyUsed: 1000),
        stats: WalletStats(),
        lastDailyReset: null, // Both daily and monthly reset needed (auto-heal)
        lastMonthlyReset: null,
      );

      await mockRepository.resetLimitsForWallets([wallet]);

      final captured = verify(() => mockBatch.update(mockDocRef, captureAny())).captured;
      expect(captured.length, equals(1));
      final Map<String, dynamic> payload = captured.single;

      expect(payload.length, equals(6));
      expect(payload['sendLimits.dailyUsed'], equals(0.0));
      expect(payload['receiveLimits.dailyUsed'], equals(0.0));
      expect(payload['sendLimits.monthlyUsed'], equals(0.0));
      expect(payload['receiveLimits.monthlyUsed'], equals(0.0));
      expect(payload.containsKey(FirebaseConstants.lastDailyReset), isTrue);
      expect(payload.containsKey(FirebaseConstants.lastMonthlyReset), isTrue);
    });
  });
}

