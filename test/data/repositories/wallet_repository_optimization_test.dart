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

  group('Wallet Aggregation Optimization (TDD)', () {
    test('getTotalBalance should read from stats/summary and fail if it still uses unbounded reads', () async {
      // ARRANGE: Setup some wallets
      await fakeFirestore.collection('wallets').add({
        'storeId': storeId,
        'isActive': true,
        'balance': 100.0,
      });
      await fakeFirestore.collection('wallets').add({
        'storeId': storeId,
        'isActive': true,
        'balance': 200.0,
      });

      // Also setup the stats/summary doc with a DIFFERENT value to distinguish where it reads from
      // If it reads from wallets collection, it will get 300.0
      // If it reads from stats/summary, it will get 500.0
      await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({'totalBalance': 500.0});

      // ACT
      final totalBalance = await repository.getTotalBalance(storeId);

      // ASSERT: Currently it should fail because it reads from the collection and gets 300.0
      expect(totalBalance, 500.0, reason: 'Should read from stats/summary document');
    });

    test('getWalletsCount should read from stats/summary and fail if it still uses unbounded reads', () async {
      // ARRANGE: Setup some wallets
      await fakeFirestore.collection('wallets').add({
        'storeId': storeId,
        'isActive': true,
        'balance': 100.0,
      });

      // Setup stats/summary with a DIFFERENT count
      await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary')
          .set({'activeWallets': 10});

      // ACT
      final count = await repository.getWalletsCount(storeId);

      // ASSERT: Currently it should fail because it reads from the collection and gets 1
      expect(count, 10, reason: 'Should read from stats/summary document');
    });
  });
}
