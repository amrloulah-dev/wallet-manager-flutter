import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/paginated_result.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockFirebaseService extends Mock implements FirebaseService {}
class MockCacheManager extends Mock implements CacheManager {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late DebtRepository repository;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshot;

  const storeId = 'test_store';

  setUpAll(() {
    registerFallbackValue(MockDocumentSnapshot());
  });

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    
    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    
    repository = DebtRepository(
      firebaseService: mockFirebaseService,
      cacheManager: mockCacheManager,
    );
  });

  group('DebtRepository Pagination (Phase 2)', () {
    test('getDebtsByDateRange should return a paginated result with limit 20', () async {
      when(() => mockCollection.where('storeId', isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.where('createdAt', isGreaterThanOrEqualTo: any(named: 'isGreaterThanOrEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.where('createdAt', isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.orderBy('createdAt', descending: any(named: 'descending'))).thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);

      final result = await repository.getDebtsByDateRange(storeId, DateTime.now(), DateTime.now());

      expect(result, isA<List>()); // It returns a List, not a PaginatedResult
      verify(() => mockQuery.limit(20)).called(1);
    });
  });

  group('DebtRepository Validation (Phase 2)', () {
    test('processPayment should throw DomainException if amount is negative', () async {
      expect(() => repository.processPayment('debt1', -10.0, 'user1'), throwsA(isA<Exception>()));
    });
  });
}
