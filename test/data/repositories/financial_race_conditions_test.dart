import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;
  late WalletRepository walletRepository;
  late StatsRepository statsRepository;
  late MockFirebaseService mockFirebaseService;

  const storeId = 'test_store';
  const walletId = 'test_wallet';

  setUp(() {
    AppErrorHandler.isTestMode = true;
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    statsRepository = StatsRepository(firestore: fakeFirestore);
    walletRepository = WalletRepository(
      firebaseService: mockFirebaseService,
      statsRepository: statsRepository,
    );
  });

  group('Financial Race Conditions (TDD - Phase 4)', () {
    test(
        'WalletRepository.debitWallet should handle concurrent-like updates safely',
        () async {
      // Setup
      final now = Timestamp.now();
      await fakeFirestore.collection('wallets').doc(walletId).set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': 1000.0,
        'isActive': true,
        'createdAt': now,
        'lastDailyReset': now,
        'lastMonthlyReset': now,
        'walletType': 'instapay',
        'walletStatus': 'active',
        'phoneNumber': '01234567890',
        'providerName': 'InstaPay',
        'createdBy': 'test_user',
        'sendLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0,
        },
        'receiveLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0,
        },
      });

      // Simulate multiple debits in rapid succession
      // Note: Future.wait in fake_cloud_firestore might still be sequential,
      // but we want to ensure the implementation is robust.
      await Future.wait([
        walletRepository.debitWallet(walletId, 100.0),
        walletRepository.debitWallet(walletId, 200.0),
        walletRepository.debitWallet(walletId, 50.0),
      ]);

      final doc = await fakeFirestore.collection('wallets').doc(walletId).get();
      expect(doc.data()!['balance'], 650.0);
    });

    test(
        'WalletRepository.debitWallet should throw DomainException for insufficient balance',
        () async {
      // Setup
      final now = Timestamp.now();
      await fakeFirestore.collection('wallets').doc(walletId).set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': 100.0,
        'isActive': true,
        'createdAt': now,
        'lastDailyReset': now,
        'lastMonthlyReset': now,
        'walletType': 'instapay',
        'walletStatus': 'active',
        'phoneNumber': '01234567890',
        'providerName': 'InstaPay',
        'createdBy': 'test_user',
        'sendLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0,
        },
        'receiveLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0,
        },
      });

      expect(() => walletRepository.debitWallet(walletId, 150.0),
          throwsA(isA<DomainException>()));
    });

    test(
        'StatsRepository.updateStatsOnWalletChange should handle concurrent-like updates safely',
        () async {
      // Setup
      await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({
        'totalWallets': 10,
        'activeWallets': 5,
        'totalBalance': 1000.0,
      });

      // Simulate multiple concurrent updates
      await Future.wait([
        statsRepository.updateStatsOnWalletChange(storeId,
            countChange: 1, activeCountChange: 1, balanceChange: 100.0),
        statsRepository.updateStatsOnWalletChange(storeId,
            countChange: -1, activeCountChange: 0, balanceChange: -50.0),
        statsRepository.updateStatsOnWalletChange(storeId,
            countChange: 2, activeCountChange: -1, balanceChange: 200.0),
      ]);

      final doc = await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .get();

      final data = doc.data()!;
      expect(data['totalWallets'], 12); // 10 + 1 - 1 + 2 = 12
      expect(data['activeWallets'], 5); // 5 + 1 + 0 - 1 = 5
      expect(data['totalBalance'], 1250.0); // 1000 + 100 - 50 + 200 = 1250
    });
  });
}
