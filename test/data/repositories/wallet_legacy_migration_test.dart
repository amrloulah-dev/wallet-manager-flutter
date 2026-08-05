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

void main() {
  late WalletRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late StatsRepository statsRepository;

  const storeId = 'store_legacy_test';
  const legacyWalletId = 'wallet_legacy_001';
  const newWalletId = 'wallet_new_001';

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

  group('Legacy Wallet Auto-Heal Integration Flow', () {
    test(
        'legacy document auto-heals timestamps on reset without corrupting custom limits or status',
        () async {
      // 1. Seed a legacy document in Firestore (no walletStatus, no sendLimits/receiveLimits, no timestamps)
      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(legacyWalletId)
          .set({
        'storeId': storeId,
        'phoneNumber': '01012345678',
        'walletType': 'vodafoneCash',
        'balance': 2500.0,
        'dailyLimit': 50000.0,
        'monthlyLimit': 150000.0,
        'createdBy': 'user_owner',
      });

      // 2. Load via WalletModel.fromFirestore (simulate provider loading)
      final docSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(legacyWalletId)
          .get();
      final loadedWallet = WalletModel.fromFirestore(docSnap);

      // Verify deserialized state
      expect(loadedWallet.walletStatus, equals(WalletStatus.inactive));
      expect(loadedWallet.sendLimits.dailyLimit, equals(50000.0));
      expect(loadedWallet.sendLimits.monthlyLimit, equals(150000.0));
      expect(loadedWallet.receiveLimits.dailyLimit, equals(50000.0));
      expect(loadedWallet.receiveLimits.monthlyLimit, equals(150000.0));
      expect(loadedWallet.lastDailyReset, isNull);
      expect(loadedWallet.lastMonthlyReset, isNull);

      // 3. Verify reset is needed due to null timestamps (auto-heal trigger)
      expect(loadedWallet.needsDailyReset, isTrue);
      expect(loadedWallet.needsMonthlyReset, isTrue);

      // 4. Trigger resetLimitsForWallets
      await repository.resetLimitsForWallets([loadedWallet]);

      // 5. Read document directly back from Firestore
      final updatedSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(legacyWalletId)
          .get();
      final data = updatedSnap.data()!;

      // Verify timestamps were written by auto-heal
      expect(data[FirebaseConstants.lastDailyReset], isNotNull);
      expect(data[FirebaseConstants.lastMonthlyReset], isNotNull);

      // Verify usage counters were set to 0.0
      expect(data['sendLimits']['dailyUsed'], equals(0.0));
      expect(data['receiveLimits']['dailyUsed'], equals(0.0));

      // CRITICAL: Verify custom legacy limit caps were NOT overwritten or removed from root
      expect(data['dailyLimit'], equals(50000.0));
      expect(data['monthlyLimit'], equals(150000.0));

      // Verify walletStatus was NOT overwritten into Firestore
      expect(data.containsKey('walletStatus'), isFalse);
    });

    test('new-format document performs clean reset with zero regressions',
        () async {
      final now = DateTime.now().subtract(const Duration(days: 2));
      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(newWalletId)
          .set({
        'storeId': storeId,
        'phoneNumber': '01012345678',
        'walletType': 'vodafoneCash',
        'walletStatus': 'active',
        'balance': 1000.0,
        'createdBy': 'user_owner',
        'lastDailyReset': Timestamp.fromDate(now),
        'lastMonthlyReset': Timestamp.fromDate(now),
        'sendLimits': {
          'dailyLimit': 10000.0,
          'dailyUsed': 2500.0,
          'monthlyLimit': 600000.0,
          'monthlyUsed': 5000.0,
        },
        'receiveLimits': {
          'dailyLimit': 10000.0,
          'dailyUsed': 1500.0,
          'monthlyLimit': 600000.0,
          'monthlyUsed': 3000.0,
        },
      });

      final docSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(newWalletId)
          .get();
      final loadedWallet = WalletModel.fromFirestore(docSnap);

      expect(loadedWallet.walletStatus, equals(WalletStatus.active));
      expect(loadedWallet.needsDailyReset, isTrue);

      await repository.resetLimitsForWallets([loadedWallet]);

      final updatedSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(newWalletId)
          .get();
      final data = updatedSnap.data()!;

      expect(data['sendLimits']['dailyUsed'], equals(0.0));
      expect(data['receiveLimits']['dailyUsed'], equals(0.0));
      expect(data['sendLimits']['dailyLimit'], equals(10000.0));
      expect(data['sendLimits']['monthlyLimit'], equals(600000.0));
      expect(data['walletStatus'], equals('active'));
    });
  });
}
