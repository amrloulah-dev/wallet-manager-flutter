import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockFirebaseService extends Mock implements FirebaseService {}
class MockCacheManager extends Mock implements CacheManager {}
class MockStatsRepository extends Mock implements StatsRepository {}

void main() {
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late MockStatsRepository mockStatsRepository;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    mockStatsRepository = MockStatsRepository();
    mockFirestore = MockFirebaseFirestore();
    
    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
  });

  group('TransactionRepository Aggregation Deletion (Phase 1)', () {
    test('TransactionRepository can be instantiated without aggregation methods', () {
      final repository = TransactionRepository(
        firebaseService: mockFirebaseService,
        cacheManager: mockCacheManager,
        statsRepository: mockStatsRepository,
      );
      expect(repository, isNotNull);
    });
  });
}
