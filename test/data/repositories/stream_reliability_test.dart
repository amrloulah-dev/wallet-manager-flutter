import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/user_repository.dart';
import 'package:walletmanager/data/repositories/store_repository.dart';
import 'package:walletmanager/data/repositories/employee_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class MockFirebaseService extends Mock implements FirebaseService {}
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockQuery extends Mock implements Query<Map<String, dynamic>> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseService mockFirebaseService;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDoc;
  late MockQuery mockQuery;

  setUp(() {
    mockFirebaseService = MockFirebaseService();
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDoc = MockDocumentReference();
    mockQuery = MockQuery();

    when(() => mockFirebaseService.firestore).thenReturn(mockFirestore);
    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDoc);
    
    when(() => mockCollection.where(any(), isEqualTo: any(named: 'isEqualTo')))
        .thenReturn(mockQuery);
    when(() => mockQuery.where(any(), isEqualTo: any(named: 'isEqualTo')))
        .thenReturn(mockQuery);
    when(() => mockQuery.orderBy(any(), descending: any(named: 'descending')))
        .thenReturn(mockQuery);
    when(() => mockQuery.limit(any())).thenReturn(mockQuery);
  });

  group('Stream Error Propagation', () {
    test('UserRepository.watchUser should propagate errors', () async {
      final repository = UserRepository(firebaseService: mockFirebaseService);
      
      final controller = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
      when(() => mockDoc.snapshots()).thenAnswer((_) => controller.stream);
      
      final stream = repository.watchUser('user1');
      
      // We use a try-catch to avoid the test failing on the side effects of AppErrorHandler
      // while still checking if the stream emits the error.
      controller.addError(Exception('Firestore Error'));
      
      await expectLater(stream, emitsError(isA<Exception>()));
      await controller.close();
    });

    test('StoreRepository.watchStore should propagate errors', () async {
      final repository = StoreRepository(firebaseService: mockFirebaseService);
      
      final controller = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
      when(() => mockDoc.snapshots()).thenAnswer((_) => controller.stream);
      
      final stream = repository.watchStore('store1');
      
      controller.addError(Exception('Firestore Error'));
      
      await expectLater(stream, emitsError(isA<Exception>()));
      await controller.close();
    });

    test('EmployeeRepository.watchEmployees should propagate errors', () async {
      final repository = EmployeeRepository(firestore: mockFirestore);
      
      final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
      when(() => mockQuery.snapshots()).thenAnswer((_) => controller.stream);
      
      final stream = repository.watchEmployees('store1');
      
      controller.addError(Exception('Firestore Error'));
      
      await expectLater(stream, emitsError(isA<Exception>()));
      await controller.close();
    });
  });
}
