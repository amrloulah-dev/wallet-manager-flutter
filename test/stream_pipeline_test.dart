import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late StatsRepository statsRepository;
  const storeId = 'test_store';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    statsRepository = StatsRepository(firestore: fakeFirestore);
  });

  group('StatsRepository - watchStatsSummary', () {
    test('should emit empty stats if document does not exist', () async {
      final stream = statsRepository.watchStatsSummary(storeId);
      
      final firstEmit = await stream.first;
      
      expect(firstEmit.totalWallets, 0);
      expect(firstEmit.activeWallets, 0);
    });

    test('should emit updated stats when document is created', () async {
      final stream = statsRepository.watchStatsSummary(storeId);
      
      // Initial emit (empty)
      // We use a list to capture emissions
      final emits = <StatsSummaryModel>[];
      final subscription = stream.listen(emits.add);
      
      // Wait for first emit
      await Future.delayed(Duration.zero);
      
      // Initialize stats
      await statsRepository.initializeStats(storeId);
      
      // Wait for second emit
      await Future.delayed(Duration.zero);
      
      expect(emits.length, 2);
      expect(emits[0].totalWallets, 0);
      expect(emits[1].totalWallets, 0); // Still 0 but initialized
      
      subscription.cancel();
    });

    test('should reflect initialized state when getStatsSummary is called first', () async {
      // 1. Initially document does not exist
      final docRef = fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary');
      
      final docBefore = await docRef.get();
      expect(docBefore.exists, false);

      // 2. Call getStatsSummary (should initialize)
      final summary = await statsRepository.getStatsSummary(storeId);
      expect(summary.totalWallets, 0);
      
      final docAfter = await docRef.get();
      expect(docAfter.exists, true);

      // 3. Watch stats summary
      final stream = statsRepository.watchStatsSummary(storeId);
      final firstEmit = await stream.first;
      
      expect(firstEmit.totalWallets, 0);
      // exists should be true now, so it should not be the 'empty()' default from watchStatsSummary's else block
    });
  });
}
