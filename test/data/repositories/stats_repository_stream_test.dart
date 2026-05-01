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
    test('watchStatsSummary should emit empty stats if document does not exist (without writing)', () async {
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

    test('watchStatsSummary should emit updated stats when document is updated', () async {
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
  });
}
