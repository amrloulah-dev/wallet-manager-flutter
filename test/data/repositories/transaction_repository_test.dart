import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/data/models/transaction_model.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

class MockFirebaseService extends Mock implements FirebaseService {}

class MockCacheManager extends Mock implements CacheManager {}

class MockStatsRepository extends Mock implements StatsRepository {}

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late TransactionRepository repository;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late MockStatsRepository mockStatsRepository;
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
    mockStatsRepository = MockStatsRepository();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);

    repository = TransactionRepository(
      firebaseService: mockFirebaseService,
      cacheManager: mockCacheManager,
      statsRepository: mockStatsRepository,
    );
  });

  group('TransactionRepository Pagination (Phase 4 Refactor)', () {
    test('getAllTransactions should return a paginated result with limit 20',
        () async {
      when(() => mockCollection.where('storeId',
          isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() =>
              mockQuery.where('isDeleted', isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs)
          .thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);

      final result = await repository.getAllTransactions(storeId);

      expect(result, isA<PaginatedResult<TransactionModel>>());
      verify(() => mockQuery.limit(20)).called(1);
    });

    test('getAllTransactions should use explicit lastDocument parameter',
        () async {
      final mockDoc = MockQueryDocumentSnapshot();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn({
        'transactionId': 'test_id',
        'storeId': 'store_id',
        'walletId': 'wallet_id',
        'transactionType': 'deposit',
        'amount': 100.0,
        'transactionDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'createdBy': 'user1',
        'isDeleted': false,
      });

      when(() => mockCollection.where('storeId',
          isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() =>
              mockQuery.where('isDeleted', isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.startAfterDocument(any())).thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs)
          .thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[mockDoc]);

      await repository.getAllTransactions(storeId, lastDocument: mockDoc);

      verify(() => mockQuery.startAfterDocument(mockDoc)).called(1);
    });

    test(
        'getTransactionsByDateRange should use explicit lastDocument parameter',
        () async {
      final mockDoc = MockQueryDocumentSnapshot();
      when(() => mockDoc.id).thenReturn('test_id');
      when(() => mockDoc.data()).thenReturn({
        'transactionId': 'test_id',
        'storeId': storeId,
        'walletId': 'wallet_id',
        'transactionType': 'deposit',
        'amount': 100.0,
        'transactionDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'createdBy': 'user1',
        'isDeleted': false,
      });

      when(() => mockCollection.where('storeId',
          isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.where('transactionDate',
              isGreaterThanOrEqualTo: any(named: 'isGreaterThanOrEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.where('transactionDate',
              isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo')))
          .thenReturn(mockQuery);
      when(() =>
              mockQuery.where('isDeleted', isEqualTo: any(named: 'isEqualTo')))
          .thenReturn(mockQuery);
      when(() => mockQuery.orderBy('transactionDate', descending: true))
          .thenReturn(mockQuery);
      when(() => mockQuery.startAfterDocument(any())).thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs)
          .thenReturn(<QueryDocumentSnapshot<Map<String, dynamic>>>[mockDoc]);

      final now = DateTime.now();
      await repository.getTransactionsByDateRange(storeId, now, now,
          lastDocument: mockDoc);

      verify(() => mockQuery.startAfterDocument(mockDoc)).called(1);
    });
    group('TransactionRepository Logic Fixes (Phase 4)', () {
      // ... logic tests ...
    });
  });
}
