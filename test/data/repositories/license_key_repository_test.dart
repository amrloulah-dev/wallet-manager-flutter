import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';

void main() {
  late LicenseKeyRepository repository;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repository = LicenseKeyRepository(firestore: fakeFirestore);
  });

  group('LicenseKeyRepository Expiry Logic', () {
    test('activateLicenseKey should calculate expiry date precisely using months', () async {
      final keyId = 'key1';
      final storeId = 'store1';
      final expiryMonths = 6;

      // Setup initial state
      await fakeFirestore.collection(FirebaseConstants.licenseKeysCollection).doc(keyId).set({
        'keyId': keyId,
        'licenseKey': 'TEST-KEY',
        'isUsed': false,
        'expiryMonths': expiryMonths,
      });

      await fakeFirestore.collection(FirebaseConstants.storesCollection).doc(storeId).set({
        'storeId': storeId,
        'subscription': {
          'status': 'trial',
        }
      });

      final now = DateTime.now();
      // Execute activation
      await repository.activateLicenseKey(keyId: keyId, storeId: storeId);

      // Verify final state
      final storeSnap = await fakeFirestore.collection(FirebaseConstants.storesCollection).doc(storeId).get();
      final expiryDate = (storeSnap.data()?['subscription']['endDate'] as Timestamp).toDate();

      // Precise expectation
      final expectedExpiry = DateTime(
        now.year,
        now.month + expiryMonths,
        now.day,
        now.hour,
        now.minute,
      );

      // We allow a small difference due to processing time, but it should NOT be exactly 180 days (30*6)
      // if the month has 31 days.
      expect(expiryDate.year, expectedExpiry.year);
      expect(expiryDate.month, expectedExpiry.month);
      expect(expiryDate.day, expectedExpiry.day);
    });
  });
}
