import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late SubscriptionRepository repository;

  const storeId = 'test_store';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test_uid');

    repository = SubscriptionRepository(
      firestore: fakeFirestore,
      auth: mockAuth,
    );
  });

  group('TOCTOU Registration Race (TDD)', () {
    test('verifyDevice should create a registration with server timestamps', () async {
      // ACT
      await repository.verifyDevice(storeId);

      // ASSERT
      final registrations = await fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('device_registrations')
          .get();
      
      expect(registrations.docs.length, 1);
      final data = registrations.docs.first.data();
      expect(data[FirebaseConstants.firstSeenAt], isNotNull);
      expect(data[FirebaseConstants.lastSeenAt], isNotNull);
      expect(data['ownerUid'], 'test_uid');
    });

    test('verifyDevice should update existing registration', () async {
      // ARRANGE
      final deviceId = 'unsupported_device_type'; 
      final docRef = fakeFirestore
          .collection('stores')
          .doc(storeId)
          .collection('device_registrations')
          .doc(deviceId);
      
      final oldDate = DateTime(2020, 1, 1);
      await docRef.set({
        FirebaseConstants.firstSeenAt: oldDate,
        FirebaseConstants.lastSeenAt: oldDate,
        'ownerUid': 'old_uid',
      });

      // ACT
      await repository.verifyDevice(storeId);

      // ASSERT
      final doc = await docRef.get();
      final data = doc.data()!;
      expect((data[FirebaseConstants.firstSeenAt] as Timestamp).toDate(), oldDate); // Should not change
      expect((data[FirebaseConstants.lastSeenAt] as Timestamp).toDate(), isNot(oldDate)); // Should be updated
      expect(data['ownerUid'], 'test_uid');
    });
  });
}
