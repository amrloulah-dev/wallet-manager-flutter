import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference<Map<String, dynamic>> {}
class MockDocumentReference extends Mock implements DocumentReference<Map<String, dynamic>> {}
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late SubscriptionRepository repository;
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference mockCollection;
  late MockDocumentReference mockDocRef;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockDocumentSnapshot mockSnapshot;

  setUpAll(() {
    registerFallbackValue(SetOptions(merge: true));
  });

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockDocRef = MockDocumentReference();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockSnapshot = MockDocumentSnapshot();

    when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
    when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test_uid');

    repository = SubscriptionRepository(
      firestore: mockFirestore,
      auth: mockAuth,
    );
  });

  group('SubscriptionRepository', () {
    test('verifyDevice should use device_registrations subcollection and include ownerUid', () async {
      const storeId = 'test_store';
      
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.collection('device_registrations')).thenReturn(mockCollection);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(false);
      when(() => mockDocRef.set(any(), any())).thenAnswer((_) async => {});

      await repository.verifyDevice(storeId);

      verify(() => mockDocRef.collection('device_registrations')).called(1);
      verify(() => mockDocRef.set(
        any(that: containsPair('ownerUid', 'test_uid')),
        any(),
      )).called(1);
    });

    test('hasDeviceConsumedTrial should use device_registrations root collection', () async {
      when(() => mockFirestore.collection('device_registrations')).thenReturn(mockCollection);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.data()).thenReturn({'trialCount': 1});

      final result = await repository.hasDeviceConsumedTrial();

      expect(result, isTrue);
      verify(() => mockFirestore.collection('device_registrations')).called(1);
    });
  });
}
