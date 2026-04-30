import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late WalletRepository repository;
  late MockFirebaseService mockFirebaseService;

  const storeId = 'test_store';
  const walletId = 'test_wallet';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);

    final statsRepository = StatsRepository(firestore: fakeFirestore);
    repository = WalletRepository(
      firebaseService: mockFirebaseService,
      statsRepository: statsRepository,
    );
  });

  group('Atomic Stats Sync (TDD)', () {
    test('toggleWalletStatus should update both wallet and stats atomically', () async {
      // ARRANGE
      await fakeFirestore.collection('stores').doc(storeId).set({
        'name': 'Test Store',
        'stats': {'activeWallets': 1}, // Legacy root field
      });

      await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({'activeWallets': 1, 'totalBalance': 100.0});

      final now = DateTime.now();
      await fakeFirestore.collection('wallets').doc(walletId).set({
        'walletId': walletId,
        'storeId': storeId,
        'isActive': true,
        'balance': 100.0,
        'createdAt': Timestamp.fromDate(now),
        'lastDailyReset': Timestamp.fromDate(now),
        'lastMonthlyReset': Timestamp.fromDate(now),
        'walletType': 'vodafoneCash',
        'walletStatus': 'active',
        'phoneNumber': '01012345678',
        'providerName': 'Vodafone',
        'isDeleted': false,
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
        'stats': {
          'totalTransactions': 0,
          'totalSentAmount': 0.0,
          'totalReceivedAmount': 0.0,
          'totalCommission': 0.0,
          'totalServiceFee': 0.0,
        },
      });

      // ACT
      await repository.setWalletActiveStatus(walletId, false);

      // ASSERT
      final walletDoc = await fakeFirestore.collection('wallets').doc(walletId).get();
      expect(walletDoc.data()!['isActive'], false);

      final summaryDoc = await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .get();
      expect(summaryDoc.data()!['activeWallets'], 0);
      expect(summaryDoc.data()!['totalBalance'], 0.0);

      // Verify legacy root field is NOT updated (or is removed/ignored)
      // The plan says "remove dual-write to legacy root stats fields"
      final storeDoc = await fakeFirestore.collection('stores').doc(storeId).get();
      expect(storeDoc.data()!['stats']['activeWallets'], 1, 
          reason: 'Legacy root field should not have been updated');
    });
  });
}
