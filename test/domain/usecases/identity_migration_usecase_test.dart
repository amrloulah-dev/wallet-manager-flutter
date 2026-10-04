import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/domain/usecases/identity_migration_usecase.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IdentityMigrationUseCase useCase;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    useCase = IdentityMigrationUseCase(firestore: fakeFirestore);
  });

  group('IdentityMigrationUseCase', () {
    test('skips employees where doc.id == firebaseUid or firebaseUid is empty',
        () async {
      const storeId = 'store_1';
      const uid1 = 'auth_uid_1';

      // Already migrated employee
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(uid1)
          .set({
        'storeId': storeId,
        'role': 'employee',
        'fullName': 'Migrated Employee',
        'firebaseUid': uid1,
        'isActive': true,
        'createdAt': DateTime.now(),
        'lastLogin': DateTime.now(),
      });

      // Employee without firebaseUid
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('legacy_no_uid')
          .set({
        'storeId': storeId,
        'role': 'employee',
        'fullName': 'No UID Employee',
        'firebaseUid': null,
        'isActive': true,
        'createdAt': DateTime.now(),
        'lastLogin': DateTime.now(),
      });

      await useCase.executeMigration(storeId);

      // Verify docs unchanged
      final doc1 = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(uid1)
          .get();
      expect(doc1.exists, isTrue);

      final doc2 = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc('legacy_no_uid')
          .get();
      expect(doc2.exists, isTrue);
    });

    test(
        'migrates mismatched employee and updates foreign keys across wallets, transactions, debts, and pin_locks',
        () async {
      const storeId = 'store_1';
      const oldDocId = 'auto_gen_doc_123';
      const authUid = 'firebase_auth_uid_456';
      const hashedPin = 'hashed_pin_abc';

      // 1. Create mismatched employee
      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(oldDocId)
          .set({
        'storeId': storeId,
        'role': 'employee',
        'fullName': 'Legacy Employee',
        'firebaseUid': authUid,
        'isActive': true,
        'createdAt': DateTime.now(),
        'lastLogin': DateTime.now(),
      });

      // 2. Create wallet with createdBy == oldDocId
      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc('w1')
          .set({
        'storeId': storeId,
        'name': 'Cash Wallet',
        'createdBy': oldDocId,
        'isActive': true,
      });

      // 3. Create transaction with createdBy / createdById / updatedBy / deletedBy == oldDocId
      await fakeFirestore
          .collection(FirebaseConstants.transactions)
          .doc('t1')
          .set({
        'storeId': storeId,
        'createdBy': oldDocId,
        'createdById': oldDocId,
        'updatedBy': oldDocId,
        'deletedBy': oldDocId,
      });

      // 4. Create debt with createdBy / markedPaidBy / lastUpdatedBy == oldDocId
      await fakeFirestore.collection(FirebaseConstants.debts).doc('d1').set({
        'storeId': storeId,
        'createdBy': oldDocId,
        'markedPaidBy': oldDocId,
        'lastUpdatedBy': oldDocId,
      });

      // 5. Create pin_lock with userId == oldDocId
      await fakeFirestore
          .doc(FirebaseConstants.pinLockPath(storeId, hashedPin))
          .set({
        'userId': oldDocId,
        'createdAt': DateTime.now(),
      });

      // Execute migration
      await useCase.executeMigration(storeId);

      // Verify old employee doc deleted
      final oldUserDoc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(oldDocId)
          .get();
      expect(oldUserDoc.exists, isFalse);

      // Verify new employee doc created at authUid
      final newUserDoc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(authUid)
          .get();
      expect(newUserDoc.exists, isTrue);
      expect(newUserDoc.data()?['fullName'], equals('Legacy Employee'));

      // Verify wallet updated
      final walletDoc = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc('w1')
          .get();
      expect(walletDoc.data()?['createdBy'], equals(authUid));

      // Verify transaction updated
      final txDoc = await fakeFirestore
          .collection(FirebaseConstants.transactions)
          .doc('t1')
          .get();
      expect(txDoc.data()?['createdBy'], equals(authUid));
      expect(txDoc.data()?['createdById'], equals(authUid));
      expect(txDoc.data()?['updatedBy'], equals(authUid));
      expect(txDoc.data()?['deletedBy'], equals(authUid));

      // Verify debt updated
      final debtDoc = await fakeFirestore
          .collection(FirebaseConstants.debts)
          .doc('d1')
          .get();
      expect(debtDoc.data()?['createdBy'], equals(authUid));
      expect(debtDoc.data()?['markedPaidBy'], equals(authUid));
      expect(debtDoc.data()?['lastUpdatedBy'], equals(authUid));

      // Verify pin_lock updated
      final pinLockDoc = await fakeFirestore
          .doc(FirebaseConstants.pinLockPath(storeId, hashedPin))
          .get();
      expect(pinLockDoc.data()?['userId'], equals(authUid));
    });

    test('migration is idempotent', () async {
      const storeId = 'store_1';
      const oldDocId = 'auto_gen_doc_789';
      const authUid = 'firebase_auth_uid_789';

      await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(oldDocId)
          .set({
        'storeId': storeId,
        'role': 'employee',
        'fullName': 'Idempotent Test',
        'firebaseUid': authUid,
        'isActive': true,
        'createdAt': DateTime.now(),
        'lastLogin': DateTime.now(),
      });

      // Run migration 1st time
      await useCase.executeMigration(storeId);

      // Run migration 2nd time
      await useCase.executeMigration(storeId);

      final userDoc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(authUid)
          .get();
      expect(userDoc.exists, isTrue);

      final oldUserDoc = await fakeFirestore
          .collection(FirebaseConstants.usersCollection)
          .doc(oldDocId)
          .get();
      expect(oldUserDoc.exists, isFalse);
    });
  });
}
