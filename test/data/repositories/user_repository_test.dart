import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseService extends Mock implements FirebaseService {}

void main() {
  late UserRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseService mockFirebaseService;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockFirebaseService = MockFirebaseService();
    when(() => mockFirebaseService.firestore).thenReturn(fakeFirestore);
    repository = UserRepository(firebaseService: mockFirebaseService);
  });

  group('UserRepository Atomic Stats Verification', () {
    test(
        'updateEmployeeStats should update stats atomically without pre-fetching user',
        () async {
      final userId = 'u1';
      final userPath = '${FirebaseConstants.usersCollection}/$userId';

      // Setup initial state
      await fakeFirestore.doc(userPath).set({
        'userId': userId,
        'role': 'employee',
        'createdAt': Timestamp.now(),
        'lastLogin': Timestamp.now(),
        'stats': {
          'totalTransactions': 5,
          'totalCommission': 50.0,
          'totalDebtsCreated': 2,
        }
      });

      // Execute update
      await repository.updateEmployeeStats(
        userId: userId,
        incrementTransactions: 1,
        incrementCommission: 10.0,
        incrementDebts: 1,
      );

      // Verify final state
      final userSnap = await fakeFirestore.doc(userPath).get();
      final stats = userSnap.data()?['stats'];

      expect(stats['totalTransactions'], 6);
      expect(stats['totalCommission'], 60.0);
      expect(stats['totalDebtsCreated'], 3);
    });
  });

  group('UserRepository getUserById Fallback', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockUsersCollection;
    late MockDocumentReference mockDocRef;
    late MockQuery mockQuery;
    late MockQueryLimit mockQueryLimit;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockUsersCollection = MockCollectionReference();
      mockDocRef = MockDocumentReference();
      mockQuery = MockQuery();
      mockQueryLimit = MockQueryLimit();

      when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
      when(() => mockFirestore.collection(FirebaseConstants.usersCollection))
          .thenReturn(mockUsersCollection);
      when(() => mockUsersCollection.doc(any())).thenReturn(mockDocRef);
    });

    test(
        'getUserById executes fallback query when direct doc fetch throws permission-denied',
        () async {
      when(() => mockDocRef.get(any())).thenThrow(FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Permission denied',
      ));

      final mockSnapshot = MockQuerySnapshot();
      final mockDocSnapshot = MockQueryDocumentSnapshot();

      when(() => mockUsersCollection.where(FirebaseConstants.firebaseUidField,
              isEqualTo: 'emp123'))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(1)).thenReturn(mockQueryLimit);
      when(() => mockQueryLimit.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([mockDocSnapshot]);
      when(() => mockDocSnapshot.exists).thenReturn(true);
      when(() => mockDocSnapshot.id).thenReturn('emp123_doc');
      when(() => mockDocSnapshot.data()).thenReturn({
        'userId': 'emp123_doc',
        'firebaseUid': 'emp123',
        'storeId': 'store1',
        'role': 'employee',
        'fullName': 'Employee Test',
        'isActive': true,
        'createdAt': Timestamp.now(),
        'lastLogin': Timestamp.now(),
      });

      final repo = UserRepository(firebaseService: mockFirebaseService);
      final result = await repo.getUserById('emp123');

      expect(result, isNotNull);
      expect(result?.userId, 'emp123_doc');
      expect(result?.firebaseUid, 'emp123');
    });

    test('getUserById returns null when fallback query returns no documents',
        () async {
      when(() => mockDocRef.get(any())).thenThrow(FirebaseException(
        plugin: 'firestore',
        code: 'permission-denied',
        message: 'Permission denied',
      ));

      final mockSnapshot = MockQuerySnapshot();

      when(() => mockUsersCollection.where(FirebaseConstants.firebaseUidField,
              isEqualTo: 'emp999'))
          .thenReturn(mockQuery);
      when(() => mockQuery.limit(1)).thenReturn(mockQueryLimit);
      when(() => mockQueryLimit.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.docs).thenReturn([]);

      final repo = UserRepository(firebaseService: mockFirebaseService);
      final result = await repo.getUserById('emp999');

      expect(result, isNull);
    });

    test('getUserById rethrows non-permission-denied FirebaseException',
        () async {
      when(() => mockDocRef.get(any())).thenThrow(FirebaseException(
        plugin: 'firestore',
        code: 'unavailable',
        message: 'Service unavailable',
      ));

      final repo = UserRepository(firebaseService: mockFirebaseService);

      expect(
        () => repo.getUserById('emp123'),
        throwsA(isA<ServerException>()),
      );
    });
  });
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockCollectionReference extends Mock
    implements CollectionReference<Map<String, dynamic>> {}

class MockDocumentReference extends Mock
    implements DocumentReference<Map<String, dynamic>> {}

class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

class MockQueryLimit extends Mock implements Query<Map<String, dynamic>> {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {}

class MockQueryDocumentSnapshot extends Mock
    implements QueryDocumentSnapshot<Map<String, dynamic>> {}

