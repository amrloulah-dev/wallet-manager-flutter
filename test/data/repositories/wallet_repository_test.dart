import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class MockFirebaseService extends Mock implements FirebaseService {}
class MockCacheManager extends Mock implements CacheManager {}

void main() {
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
    test('creditWallet should increment balance and update stats atomically', () async {
      // Setup initial state
      await fakeFirestore.collection(FirebaseConstants.walletsCollection).doc(walletId).set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': 100.0,
        'isActive': true,
        'phoneNumber': '123',
        'walletType': 'vodafoneCash',
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'sendLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'receiveLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
      });

      final statsPath = FirebaseConstants.statsSummaryPath(storeId);
      await fakeFirestore.doc(statsPath).set({
        'totalBalance': 100.0,
      });

      // Execute
      await repository.creditWallet(walletId, 50.0);

      // Verify
      final walletSnap = await fakeFirestore.collection(FirebaseConstants.walletsCollection).doc(walletId).get();
      expect(walletSnap.data()?['balance'], 150.0);

      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['totalBalance'], 150.0);
    });

    test('debitWallet should decrement balance and update stats atomically', () async {
      // Setup initial state
      await fakeFirestore.collection(FirebaseConstants.walletsCollection).doc(walletId).set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': 200.0,
        'isActive': true,
        'phoneNumber': '123',
        'walletType': 'vodafoneCash',
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'sendLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
        'receiveLimits': {'dailyLimit': 1000.0, 'dailyUsed': 0.0, 'monthlyLimit': 5000.0, 'monthlyUsed': 0.0},
      });

      final statsPath = FirebaseConstants.statsSummaryPath(storeId);
      await fakeFirestore.doc(statsPath).set({
        'totalBalance': 200.0,
      });

      // Execute
      await repository.debitWallet(walletId, 80.0);

      // Verify
      final walletSnap = await fakeFirestore.collection(FirebaseConstants.walletsCollection).doc(walletId).get();
      expect(walletSnap.data()?['balance'], 120.0);

      final statsSnap = await fakeFirestore.doc(statsPath).get();
      expect(statsSnap.data()?['totalBalance'], 120.0);
    });
  });
}
