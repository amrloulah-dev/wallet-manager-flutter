import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/device_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late DeviceRepository repository;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test_uid');

    repository = DeviceRepository(
      firestore: mockFirestore,
      auth: mockAuth,
    );
  });

  group('DeviceRepository', () {
    test('registerDeviceUsage should include ownerUid in the payload and use device_registrations collection', () async {
      // Setup
      const deviceId = 'test_device';
      const storeId = 'test_store';
      
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async => {});

      // Act
      await repository.registerDeviceUsage(deviceId, storeId);

      // Assert
      verify(() => mockFirestore.collection('device_registrations')).called(1);
      verify(() => mockDocRef.set(
        captureAny(that: containsPair('ownerUid', 'test_uid')),
        any(),
      )).called(1);
    });
  });
}
