import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../errors/app_error_handler.dart';
import '../errors/error_severity.dart';

import 'package:flutter/foundation.dart';

class IdentityService {
  static FirebaseApp? _secondaryApp;
  @visibleForTesting
  static FirebaseAuth? authOverride;

  static Future<void> _ensureInitialized() async {
    if (authOverride != null) return;
    if (_secondaryApp != null) return;
    try {
      _secondaryApp = Firebase.app('employeeAuth');
    } catch (e) {
      try {
        _secondaryApp = await Firebase.initializeApp(
          name: 'employeeAuth',
          options: Firebase.app().options,
        );
      } catch (initError) {
        AppErrorHandler.handle(
          Exception('Failed to initialize secondary Firebase app: \$initError'),
          severity: ErrorSeverity.low,
          operation: 'IdentityService._ensureInitialized',
        );
      }
    }
  }

  static String _generateEmail(String phone, String storeId) {
    return 'emp_${phone}_$storeId@store.com';
  }

  static Future<String?> provisionIdentity({
    required String phone,
    required String storeId,
    required String pin,
  }) async {
    try {
      await _ensureInitialized();
      if (_secondaryApp == null && authOverride == null) return null;

      final email = _generateEmail(phone, storeId);
      final auth = authOverride ?? sl<FirebaseAuth>(param1: _secondaryApp!);

      try {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: pin,
        );
        return credential.user?.uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // If already in use, logic dictates we attempt to sign in to get the UID
          final credential = await auth.signInWithEmailAndPassword(
            email: email,
            password: pin,
          );
          return credential.user?.uid;
        }
        rethrow;
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.provisionIdentity',
      );
      return null;
    }
  }

  static Future<bool> updateCredential({
    required String phone,
    required String storeId,
    required String newPin,
  }) async {
    try {
      await _ensureInitialized();
      if (_secondaryApp == null && authOverride == null) return false;

      final email = _generateEmail(phone, storeId);
      final auth = authOverride ?? sl<FirebaseAuth>(param1: _secondaryApp!);

      // Unfortunately, Firebase Auth requires the user to be signed in to update password.
      // But updating from admin SDK is usually how this is done easily securely.
      // As a client SDK workaround, since we are using a secondary app, we can just sign in.
      // However, we don't have the current PIN to sign in with, as a PIN change might be a reset!
      // Wait, without old PIN, `signInWithEmailAndPassword` won't work to get the user context to updatePassword.
      // If we only have `newPin`, and no `oldPin`, Firebase Client SDK cannot reset password without an email reset flow unless signed in recently.
      // Assuming `EmployeeRepository.syncCredential` is fired by PIN change, this might require us to know the old PIN, or what if owner resets it?
      // Wait, the specification says:
      // "updateCredential({phone, storeId, newPin}) -> bool"
      // Wait! Is there an admin endpoint available? No, this is client side.
      // If the owner resets it, we might not have the old pin. But US-01 implies employee update?
      // Actually, we can use the backend or Cloud Function, but spec just says `auth.currentUser?.updatePassword`.
      // Let's implement it the best we can. If the owner updates the PIN of an employee, we can't easily sign in as the employee without the old PIN unless we reset it.
      // Let's assume the user is signed in, OR we try to sign in with `newPin` (maybe they just want to sync a changed pin?).
      // The task didn't specify `oldPin`. I will just attempt to update password if signed in. This is a best effort.
      // Actually, if we just sign in with the new PIN, maybe it's already updated? No.
      // Let's just try to get currentUser and updatePassword. If not signed in, this will fail.
      if (auth.currentUser != null && auth.currentUser?.email == email) {
        await auth.currentUser?.updatePassword(newPin);
        return true;
      } else {
        // If they are not signed in, we can't update it from the client SDK without old pin!
        throw Exception('Cannot update credential without being signed in as the target user in the secondary app.');
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.updateCredential',
      );
      return false;
    }
  }

  static Future<bool> deleteIdentity({
    required String phone,
    required String storeId,
  }) async {
    try {
      await _ensureInitialized();
      if (_secondaryApp == null && authOverride == null) return false;

      final email = _generateEmail(phone, storeId);
      final auth = authOverride ?? sl<FirebaseAuth>(param1: _secondaryApp!);

      if (auth.currentUser != null && auth.currentUser?.email == email) {
        await auth.currentUser?.delete();
        return true;
      } else {
         throw Exception('Cannot delete identity without being signed in as the target user.');
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.deleteIdentity',
      );
      return false;
    }
  }

  static Future<String?> authenticateEmployee({
    required String phone,
    required String storeId,
    required String pin,
  }) async {
    try {
      await _ensureInitialized();
      if (_secondaryApp == null && authOverride == null) return null;

      final email = _generateEmail(phone, storeId);
      final auth = authOverride ?? sl<FirebaseAuth>(param1: _secondaryApp!);

      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: pin,
      );
      return credential.user?.uid;
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.authenticateEmployee',
      );
      return null;
    }
  }
}