import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/repositories/subscription_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUser extends Mock implements User {}

void main() {
  late SubscriptionRepository repository;
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

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

  group('SubscriptionRepository', () {
    test('verifyDevice should use device_registrations subcollection and include ownerUid', () async {
      const storeId = 'test_store';
      
      await repository.verifyDevice(storeId);

      // DeviceTrackingService.getDeviceId() returns 'unsupported_device_type' in this environment
      final registrations = await fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection(FirebaseConstants.deviceRegistrationsCollection)
          .get();
      
      expect(registrations.docs.length, 1);
      expect(registrations.docs.first.data()['ownerUid'], 'test_uid');
    });

    test('hasDeviceConsumedTrial should use device_registrations root collection', () async {
      // Setup data in root collection
      // DeviceTrackingService.getDeviceId() returns 'unsupported_device_type'
      const deviceId = 'unsupported_device_type';
      
      await fakeFirestore.collection(FirebaseConstants.deviceRegistrationsCollection).doc(deviceId).set({
        'trialCount': 1,
      });

      final result = await repository.hasDeviceConsumedTrial();

      expect(result, isTrue);
    });
  });
}
