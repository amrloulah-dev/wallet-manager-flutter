import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late StatsRepository repository;

  const storeId = 'test_store';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = StatsRepository(firestore: fakeFirestore);
  });

  group('StatsRepository Stream Fixes (TDD - Phase 3)', () {
    test(
        'watchStatsSummary should emit empty stats if document does not exist (without writing)',
        () async {
      // 1. Start watching
      final stream = repository.watchStatsSummary(storeId);

      // 2. Expect an empty model initially (because doc doesn't exist)
      final stats = await stream.first;
      expect(stats.totalWallets, 0);

      // 3. Check if document was created (Should be false after fix)
      final doc = await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection(FirebaseConstants.statsCollection)
          .doc(FirebaseConstants.summaryDoc)
          .get();

      expect(doc.exists, isFalse);
    });

    test('watchStatsSummary should emit updated stats when document is updated',
        () async {
      // 1. Seed data
      final docRef = fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection(FirebaseConstants.statsCollection)
          .doc(FirebaseConstants.summaryDoc);

      await docRef.set({
        'totalWallets': 5,
        'activeWallets': 3,
        'totalBalance': 1000.0,
      });

      // 2. Watch stream (as broadcast to allow multiple listens)
      final stream = repository.watchStatsSummary(storeId).asBroadcastStream();

      final firstStats = await stream.first;
      expect(firstStats.totalWallets, 5);

      // 3. Start expecting
      final expectation = expectLater(
        stream,
        emits(predicate((StatsSummaryModel s) => s.totalWallets == 6)),
      );

      // 4. Update data
      await docRef.update({'totalWallets': 6});

      await expectation;
    });

    test('getStatsByDateRange should aggregate all numeric daily stats except totalBalance and totalWallets', () async {
      // 1. Populate stats for multiple days
      final stats1 = {
        'transactionCount': 2,
        'sendCount': 1,
        'receiveCount': 1,
        'totalSentAmount': 100.0,
        'totalReceivedAmount': 150.0,
        'totalCommission': 10.0,
        'totalServiceFee': 2.0,
        'totalAmount': 500.0,
        'totalBalance': 5000.0,
        'totalWallets': 5,
      };

      final stats2 = {
        'transactionCount': 3,
        'sendCount': 2,
        'receiveCount': 1,
        'totalSentAmount': 200.0,
        'totalReceivedAmount': 250.0,
        'totalCommission': 20.0,
        'totalServiceFee': 3.0,
        'totalAmount': 600.0,
        'totalBalance': 6000.0,
        'totalWallets': 6,
      };

      await fakeFirestore
          .doc(FirebaseConstants.dailyStatsPath(storeId, '2026-05-24'))
          .set(stats1);
      await fakeFirestore
          .doc(FirebaseConstants.dailyStatsPath(storeId, '2026-05-25'))
          .set(stats2);

      // 2. Query date range
      final start = DateTime(2026, 05, 24);
      final end = DateTime(2026, 05, 25);
      final result = await repository.getStatsByDateRange(storeId, start, end);

      // 3. Assert correct aggregation
      expect(result['transactionCount'], 5);
      expect(result['sendCount'], 3);
      expect(result['receiveCount'], 2);
      expect(result['totalSentAmount'], 300.0);
      expect(result['totalReceivedAmount'], 400.0);
      expect(result['totalCommission'], 30.0);
      expect(result['totalServiceFee'], 5.0);
      expect(result['totalAmount'], 1100.0);

      // Exclude totalBalance and totalWallets
      expect(result.containsKey('totalBalance'), isFalse);
      expect(result.containsKey('totalWallets'), isFalse);
    });
  });
}
