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
import 'package:walletmanager/data/models/stats_summary_model.dart';

import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

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
    AnalyticsService.isTestMode = true;
    AppErrorHandler.isTestMode = true;
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
    
    // Support where() - positional any() for field and value
    when(() => mockCollection.where(any(),
      isEqualTo: any(named: 'isEqualTo'),
      isNull: any(named: 'isNull'),
      isNotEqualTo: any(named: 'isNotEqualTo'),
      isLessThan: any(named: 'isLessThan'),
      isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo'),
      isGreaterThan: any(named: 'isGreaterThan'),
      isGreaterThanOrEqualTo: any(named: 'isGreaterThanOrEqualTo'),
      arrayContains: any(named: 'arrayContains'),
      arrayContainsAny: any(named: 'arrayContainsAny'),
      whereIn: any(named: 'whereIn'),
      whereNotIn: any(named: 'whereNotIn'),
    )).thenReturn(mockQuery);

    when(() => mockQuery.where(any(),
      isEqualTo: any(named: 'isEqualTo'),
      isNull: any(named: 'isNull'),
      isNotEqualTo: any(named: 'isNotEqualTo'),
      isLessThan: any(named: 'isLessThan'),
      isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo'),
      isGreaterThan: any(named: 'isGreaterThan'),
      isGreaterThanOrEqualTo: any(named: 'isGreaterThanOrEqualTo'),
      arrayContains: any(named: 'arrayContains'),
      arrayContainsAny: any(named: 'arrayContainsAny'),
      whereIn: any(named: 'whereIn'),
      whereNotIn: any(named: 'whereNotIn'),
    )).thenReturn(mockQuery);

    // Stub runTransaction to execute the handler immediately (Matched for both void and dynamic)
    when(() => mockFirestore.runTransaction<void>(any())).thenAnswer((invocation) async {
      final handler = invocation.positionalArguments[0] as Function;
      await handler(mockTransaction);
    });

    when(() => mockFirestore.runTransaction<dynamic>(any())).thenAnswer((invocation) async {
      final handler = invocation.positionalArguments[0] as Function;
      return await handler(mockTransaction);
    });

    when(() => mockTransaction.get<Map<String, dynamic>>(any())).thenAnswer((_) async => mockDocSnap);
    when(() => mockTransaction.set<Object?>(any(), any())).thenReturn(mockTransaction);
    when(() => mockTransaction.update(any(), any())).thenReturn(mockTransaction);
    when(() => mockDocSnap.exists).thenReturn(true);
    when(() => mockDocSnap.id).thenReturn(walletId);
    
    // Stub getStatsSummary to avoid Null subtype errors
    when(() => mockStatsRepository.getStatsSummary(any())).thenAnswer((_) async => StatsSummaryModel.empty());

    repository = WalletRepository(
      firebaseService: mockFirebaseService,
      cacheManager: mockCacheManager,
      statsRepository: mockStatsRepository,
    );
  });

  group('WalletRepository', () {
    test('getWalletsCount returns correctly', () async {
      final summary = StatsSummaryModel.empty().copyWith(activeWallets: 5);
      when(() => mockStatsRepository.getStatsSummary(storeId)).thenAnswer((_) async => summary);

      final count = await repository.getWalletsCount(storeId);

      expect(count, 5);
    });

    test('getWalletsCount throws ServerException on error', () async {
      when(() => mockStatsRepository.getStatsSummary(storeId)).thenThrow(Exception('Firestore error'));

      expect(() => repository.getWalletsCount(storeId), throwsA(isA<ServerException>()));
    });
   group('WalletRepository Atomicity (Phase 1)', () {
    test('creditWallet executes stats updates within the same transaction', () async {
      when(() => mockDocSnap.data()).thenReturn({
        'storeId': storeId,
        'balance': 100.0,
      });
      when(() => mockCacheManager.clearWhere(any())).thenAnswer((_) async {});
      when(() => mockCacheManager.clear(any())).thenAnswer((_) async {});

      // Patterns for creditWallet and debitWallet
      when(() => mockStatsRepository.updateStatsOnWalletChange(
        any(),
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

      // Patterns for creditWallet and debitWallet
      when(() => mockStatsRepository.updateStatsOnWalletChange(
        any(),
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
