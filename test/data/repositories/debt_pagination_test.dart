import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/repositories/debt_repository.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/paginated_result.dart';

class MockFirebaseService extends Mock implements FirebaseService {}
class MockFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockQuerySnapshot extends Mock implements QuerySnapshot<Map<String, dynamic>> {}
class MockQueryDocumentSnapshot extends Mock implements QueryDocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late DebtRepository debtRepository;
  late MockFirebaseService mockFirebaseService;
  late MockFirestore mockFirestore;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockFirestore = MockFirestore();
    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);

    debtRepository = DebtRepository(
      firebaseService: mockFirebaseService,
      cacheManager: CacheManager(),
    );
  });

  group('DebtRepository Stateless Pagination (TDD - Phase 3)', () {
    test('getDebtsByDateRange should be stateless and return PaginatedResult', () async {
      final mockCollection = MockCollectionReference();
      final mockQuery = MockQuery();
      final mockSnapshot = MockQuerySnapshot();
      final mockDoc = MockQueryDocumentSnapshot();

      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isGreaterThanOrEqualTo: any(named: 'isGreaterThanOrEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.where(any(), isLessThanOrEqualTo: any(named: 'isLessThanOrEqualTo'))).thenReturn(mockQuery);
      when(() => mockQuery.orderBy(any(), descending: any(named: 'descending'))).thenReturn(mockQuery);
      when(() => mockQuery.limit(any())).thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([mockDoc]);
      when(() => mockDoc.id).thenReturn('d1');
      when(() => mockDoc.exists).thenReturn(true);
      when(() => mockDoc.data()).thenReturn({
        'storeId': 's1',
        'customerName': 'C1',
        'amountDue': 100.0,
        'totalAmount': 100.0,
        'debtType': 'credit',
        'debtStatus': 'open',
        'debtDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'createdBy': 'u1',
      });

      // The new method should exist and return PaginatedResult
      // This will fail to compile if the method signature hasn't changed yet.
      final result = await debtRepository.getDebtsByDateRange(
        's1',
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now(),
        lastDocument: null,
      );

      expect(result, isA<PaginatedResult<DebtModel>>());
      expect(result.items.length, 1);
      expect(result.lastDocument, isNotNull);
    });
  });
}
