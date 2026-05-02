import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:walletmanager/data/repositories/wallet_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/paginated_result.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/models/wallet_model.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockFirebaseService extends Mock implements FirebaseService {}
class MockCacheManager extends Mock implements CacheManager {}
class MockStatsRepository extends Mock implements StatsRepository {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}
class MockTransaction extends Mock implements Transaction {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class FakeDocumentReferenceMap extends Fake implements DocumentReference<Map<String, dynamic>> {}
class MockAggregateQuery extends Mock implements AggregateQuery {}
class MockAggregateQuerySnapshot extends Mock implements AggregateQuerySnapshot {}

void main() {
  late WalletRepository repository;
  late MockFirebaseService mockFirebaseService;
  late MockCacheManager mockCacheManager;
  late MockStatsRepository mockStatsRepository;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuery mockQuery;
  late MockQuerySnapshot mockSnapshot;
  late MockTransaction mockTransaction;
  late MockDocumentReference mockDocRef;
  late MockDocumentSnapshot mockDocSnap;

  const storeId = 'test_store';
  const walletId = 'test_wallet';

  setUpAll(() {
    registerFallbackValue(MockDocumentSnapshot());
    registerFallbackValue(FakeDocumentReferenceMap());
    registerFallbackValue(MockTransaction());
  });

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockCacheManager = MockCacheManager();
    mockStatsRepository = MockStatsRepository();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    mockTransaction = MockTransaction();
    mockDocRef = MockDocumentReference();
    mockDocSnap = MockDocumentSnapshot();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    
    // Support where() - SIMPLER STUB
    when(() => mockCollection.where(any(), isEqualTo: any())).thenReturn(mockQuery);
    when(() => mockQuery.where(any(), isEqualTo: any())).thenReturn(mockQuery);

    // Stub runTransaction to execute the handler immediately and return Future<void>
    when(() => mockFirestore.runTransaction<void>(any())).thenAnswer((invocation) async {
      final handler = invocation.positionalArguments[0] as Future<void> Function(Transaction);
      await handler(mockTransaction);
      return Future<void>.value();
    });

    when(() => mockTransaction.get<Map<String, dynamic>>(any())).thenAnswer((_) async => mockDocSnap);
    when(() => mockTransaction.set<Object?>(any(), any())).thenReturn(mockTransaction);
    when(() => mockTransaction.update(any(), any())).thenReturn(mockTransaction);
    when(() => mockDocSnap.exists).thenReturn(true);
    when(() => mockDocSnap.id).thenReturn(walletId);

    repository = WalletRepository(
      firebaseService: mockFirebaseService,
      cacheManager: mockCacheManager,
      statsRepository: mockStatsRepository,
    );
  });

  group('WalletRepository', () {
    test('getWalletsCount returns correctly', () async {
      final mockAggregateQuery = MockAggregateQuery();
      final mockAggregateSnapshot = MockAggregateQuerySnapshot();
      
      when(() => mockQuery.count()).thenReturn(mockAggregateQuery);
      when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
      when(() => mockAggregateSnapshot.count).thenReturn(5);

      final count = await repository.getWalletsCount(storeId);

      expect(count, 5);
    });

    test('getWalletsCount throws ServerException on error', () async {
      when(() => mockQuery.count()).thenThrow(Exception('Firestore error'));

      expect(() => repository.getWalletsCount(storeId), throwsA(isA<Exception>()));
    });
   group('WalletRepository Atomicity (Phase 1)', () {
    test('creditWallet executes stats updates within the same transaction', () async {
      when(() => mockDocSnap.data()).thenReturn({
        'storeId': storeId,
        'balance': 100.0,
      });
      when(() => mockCacheManager.clearWhere(any())).thenAnswer((_) async {});
      when(() => mockCacheManager.clear(any())).thenAnswer((_) async {});

      when(() => mockStatsRepository.updateStatsOnWalletChange(
        storeId,
        balanceChange: any(named: 'balanceChange'),
        firestoreTransaction: any(named: 'firestoreTransaction'),
      )).thenAnswer((_) async {});

      await repository.creditWallet(walletId, 50.0);

      verify(() => mockStatsRepository.updateStatsOnWalletChange(
        storeId,
        balanceChange: 50.0,
        firestoreTransaction: mockTransaction,
      )).called(1);
    });

    test('debitWallet executes stats updates within the same transaction', () async {
      when(() => mockDocSnap.data()).thenReturn({
        'storeId': storeId,
        'balance': 100.0,
      });
      when(() => mockCacheManager.clearWhere(any())).thenAnswer((_) async {});
      when(() => mockCacheManager.clear(any())).thenAnswer((_) async {});

      when(() => mockStatsRepository.updateStatsOnWalletChange(
        storeId,
        balanceChange: any(named: 'balanceChange'),
        firestoreTransaction: any(named: 'firestoreTransaction'),
      )).thenAnswer((_) async {});

      await repository.debitWallet(walletId, 50.0);

      verify(() => mockStatsRepository.updateStatsOnWalletChange(
        storeId,
        balanceChange: -50.0,
        firestoreTransaction: mockTransaction,
      )).called(1);
    });
  });
});
}
