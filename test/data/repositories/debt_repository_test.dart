import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockFirebaseService extends Mock implements FirebaseService {}
class MockCacheManager extends Mock implements CacheManager {}

void main() {
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    mockFirestore = MockFirebaseFirestore();
    
    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
  });

  group('DebtRepository Aggregation Deletion (Phase 1)', () {
    test('DebtRepository can be instantiated without aggregation methods', () {
      final repository = DebtRepository(
        firebaseService: mockFirebaseService,
        cacheManager: mockCacheManager,
      );
      expect(repository, isNotNull);
    });
  });
}
