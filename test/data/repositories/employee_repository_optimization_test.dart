import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}
class MockAggregateQuery extends Mock implements AggregateQuery {}
class MockAggregateQuerySnapshot extends Mock implements AggregateQuerySnapshot {}

void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockQuery mockQuery;
  late MockAggregateQuery mockAggregateQuery;
  late MockAggregateQuerySnapshot mockAggregateSnapshot;
  late EmployeeRepository repository;

  const storeId = 'test_store';

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockAggregateQuery = MockAggregateQuery();
    mockAggregateSnapshot = MockAggregateQuerySnapshot();

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
    when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo'))).thenReturn(mockQuery);
    
    repository = EmployeeRepository(firestore: mockFirestore);
  });

  group('Employee Count Optimization (TDD)', () {
    test('getEmployeesCount should use .count() aggregation', () async {
      // ARRANGE
      when(() => mockQuery.count()).thenReturn(mockAggregateQuery);
      when(() => mockAggregateQuery.get()).thenAnswer((_) async => mockAggregateSnapshot);
      when(() => mockAggregateSnapshot.count).thenReturn(5);

      // ACT
      final count = await repository.getEmployeesCount(storeId);

      // ASSERT
      expect(count, 5);
      verify(() => mockQuery.count()).called(1);
    });
  });
}
