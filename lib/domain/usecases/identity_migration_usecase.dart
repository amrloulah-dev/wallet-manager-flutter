import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/data/services/firebase_service.dart';

/// Transparently migrates legacy employee documents where `doc.id != firebaseUid`
/// to `doc.id == firebaseUid` and updates all foreign keys across collections
/// (wallets, transactions, debts, pin_locks) atomically using WriteBatch.
class IdentityMigrationUseCase {
  final FirebaseFirestore _firestore;

  IdentityMigrationUseCase({FirebaseFirestore? firestore})
      : _firestore = firestore ??
            (sl.isRegistered<FirebaseService>()
                ? sl<FirebaseService>().firestore
                : (sl.isRegistered<FirebaseFirestore>()
                    ? sl<FirebaseFirestore>()
                    : FirebaseFirestore.instance));

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection(FirebaseConstants.usersCollection);

  CollectionReference<Map<String, dynamic>> get _walletsCollection =>
      _firestore.collection(FirebaseConstants.walletsCollection);

  CollectionReference<Map<String, dynamic>> get _transactionsCollection =>
      _firestore.collection(FirebaseConstants.transactions);

  CollectionReference<Map<String, dynamic>> get _debtsCollection =>
      _firestore.collection(FirebaseConstants.debts);

  Future<void> executeMigration(String currentStoreId) async {
    try {
      debugPrint(
          '🔄 [IdentityMigrationUseCase] Checking legacy employee documents for store: $currentStoreId');

      // 1. Fetch all employee documents for this store
      final employeesSnapshot = await _usersCollection
          .where(FirebaseConstants.storeId, isEqualTo: currentStoreId)
          .where(FirebaseConstants.role, isEqualTo: UserRole.employee.name)
          .get();

      if (employeesSnapshot.docs.isEmpty) {
        debugPrint(
            'ℹ️ [IdentityMigrationUseCase] No employee documents found for store: $currentStoreId');
        return;
      }

      // 2. Identify mismatched employees: doc.id != firebaseUid && firebaseUid != null && isNotEmpty
      final mismatchedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in employeesSnapshot.docs) {
        final firebaseUid = doc.data()['firebaseUid'] as String?;
        if (firebaseUid != null &&
            firebaseUid.isNotEmpty &&
            doc.id != firebaseUid) {
          mismatchedDocs.add(doc);
        }
      }

      if (mismatchedDocs.isEmpty) {
        debugPrint(
            '✅ [IdentityMigrationUseCase] All employee documents in store $currentStoreId are unified (doc.id == firebaseUid)');
        return;
      }

      debugPrint(
          '🚨 [IdentityMigrationUseCase] Found ${mismatchedDocs.length} legacy employee(s) requiring identity migration');

      WriteBatch batch = _firestore.batch();
      int opCount = 0;

      Future<void> addOperation(
          void Function(WriteBatch currentBatch) op) async {
        if (opCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          opCount = 0;
        }
        op(batch);
        opCount++;
      }

      for (final doc in mismatchedDocs) {
        final oldDocId = doc.id;
        final data = doc.data();
        final firebaseUid = data['firebaseUid'] as String;

        // a. Create new employee doc with doc.id == firebaseUid
        final newDocRef = _usersCollection.doc(firebaseUid);
        await addOperation((b) => b.set(newDocRef, data));

        // b. Delete old employee doc
        final oldDocRef = _usersCollection.doc(oldDocId);
        await addOperation((b) => b.delete(oldDocRef));

        // c. Update Wallets: createdBy == oldDocId
        final walletsSnapshot = await _walletsCollection
            .where(FirebaseConstants.storeId, isEqualTo: currentStoreId)
            .where('createdBy', isEqualTo: oldDocId)
            .get();

        for (final walletDoc in walletsSnapshot.docs) {
          await addOperation(
              (b) => b.update(walletDoc.reference, {'createdBy': firebaseUid}));
        }

        // d. Update Transactions: createdBy, createdById, updatedBy, deletedBy == oldDocId
        final txSnapshot = await _transactionsCollection
            .where(FirebaseConstants.storeId, isEqualTo: currentStoreId)
            .get();

        for (final txDoc in txSnapshot.docs) {
          final txData = txDoc.data();
          final updates = <String, dynamic>{};

          if (txData['createdBy'] == oldDocId) {
            updates['createdBy'] = firebaseUid;
          }
          if (txData['createdById'] == oldDocId) {
            updates['createdById'] = firebaseUid;
          }
          if (txData['updatedBy'] == oldDocId) {
            updates['updatedBy'] = firebaseUid;
          }
          if (txData['deletedBy'] == oldDocId) {
            updates['deletedBy'] = firebaseUid;
          }

          if (updates.isNotEmpty) {
            await addOperation((b) => b.update(txDoc.reference, updates));
          }
        }

        // e. Update Debts: createdBy, markedPaidBy, lastUpdatedBy == oldDocId
        final debtsSnapshot = await _debtsCollection
            .where(FirebaseConstants.storeId, isEqualTo: currentStoreId)
            .get();

        for (final debtDoc in debtsSnapshot.docs) {
          final debtData = debtDoc.data();
          final updates = <String, dynamic>{};

          if (debtData['createdBy'] == oldDocId) {
            updates['createdBy'] = firebaseUid;
          }
          if (debtData['markedPaidBy'] == oldDocId) {
            updates['markedPaidBy'] = firebaseUid;
          }
          if (debtData['lastUpdatedBy'] == oldDocId) {
            updates['lastUpdatedBy'] = firebaseUid;
          }

          if (updates.isNotEmpty) {
            await addOperation((b) => b.update(debtDoc.reference, updates));
          }
        }

        // f. Update Pin Locks subcollection: userId == oldDocId
        final pinLocksCollection = _firestore.collection(
            FirebaseConstants.pinLocksSubcollection(currentStoreId));
        final pinLocksSnapshot =
            await pinLocksCollection.where('userId', isEqualTo: oldDocId).get();

        for (final pinLockDoc in pinLocksSnapshot.docs) {
          await addOperation(
              (b) => b.update(pinLockDoc.reference, {'userId': firebaseUid}));
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }

      debugPrint(
          '🎉 [IdentityMigrationUseCase] Identity migration completed successfully for store: $currentStoreId');
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
        e.toString(),
        'IdentityMigrationUseCase.executeMigration',
        stackTrace: stack,
      );
      // Silent migration: do not rethrow to prevent breaking owner login flow
    }
  }
}
