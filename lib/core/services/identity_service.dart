import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../errors/app_error_handler.dart';
import '../errors/app_exceptions.dart';
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
      if (Firebase.apps.any((app) => app.name == 'employeeAuth')) {
        _secondaryApp = Firebase.app('employeeAuth');
      } else {
        _secondaryApp = await Firebase.initializeApp(
          name: 'employeeAuth',
          options: Firebase.app().options,
        );
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        severity: ErrorSeverity.low,
        operation: 'IdentityService._ensureInitialized',
        stackTrace: stack,
      );
    }
  }

  static String _generateEmail(String phone, String storeId) {
    return 'emp_${phone}_$storeId@store.com';
  }

  static Future<String?> provisionIdentity({
    String? phone,
    String? storeId,
    String? pin,
    String? email,
    String? rawPin,
  }) async {
    final effectivePin = rawPin ?? pin ?? '';
    final effectiveEmail = email ??
        (phone != null && storeId != null
            ? _generateEmail(phone, storeId)
            : '');

    // Override path for mocktail unit tests
    if (authOverride != null) {
      try {
        final credential = await authOverride!.createUserWithEmailAndPassword(
          email: effectiveEmail,
          password: effectivePin,
        );
        final user = credential.user;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) return user.uid;
        }
        return null;
      } on FirebaseAuthException catch (e, stack) {
        if (e.code == 'email-already-in-use') {
          final credential = await authOverride!.signInWithEmailAndPassword(
            email: effectiveEmail,
            password: effectivePin,
          );
          final user = credential.user;
          if (user != null) {
            final token = await user.getIdToken();
            if (token != null) return user.uid;
          }
          return null;
        }
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          severity: ErrorSeverity.low,
          operation: 'IdentityService.provisionIdentity',
        );
        rethrow;
      }
    }

    // Production runtime path using Secondary Firebase App pattern
    final appName = 'ProvisioningApp_${DateTime.now().millisecondsSinceEpoch}';
    final tempApp = await Firebase.initializeApp(
      name: appName,
      options: Firebase.app().options,
    );

    try {
      final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final userCredential = await tempAuth.createUserWithEmailAndPassword(
        email: effectiveEmail,
        password: effectivePin,
      );
      final user = userCredential.user;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) return user.uid;
      }
      return null;
    } on FirebaseAuthException catch (e, stack) {
      if (e.code == 'email-already-in-use') {
        final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
        final credential = await tempAuth.signInWithEmailAndPassword(
          email: effectiveEmail,
          password: effectivePin,
        );
        final user = credential.user;
        if (user != null) {
          final token = await user.getIdToken();
          if (token != null) return user.uid;
        }
        return null;
      }
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.provisionIdentity',
      );
      rethrow;
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.provisionIdentity',
      );
      return null;
    } finally {
      await tempApp.delete(); // CRITICAL: Prevent memory leaks
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

      if (auth.currentUser != null && auth.currentUser?.email == email) {
        await auth.currentUser?.updatePassword(newPin);
        return true;
      } else {
        throw Exception(
            'Cannot update credential without being signed in as the target user in the secondary app.');
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
        throw Exception(
            'Cannot delete identity without being signed in as the target user.');
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
      final email = _generateEmail(phone, storeId);
      final auth = authOverride ?? FirebaseAuth.instance;

      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: pin,
      );

      final user = credential.user;
      if (user != null) {
        // Enforce Report 1: M-2 - Mandate a valid token before returning UID
        final token = await user.getIdToken();
        if (token != null) {
          return user.uid;
        }
      }
      throw AuthException('auth_error_invalid_credentials');
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.authenticateEmployee',
      );
      throw AuthException('auth_error_invalid_credentials');
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'IdentityService.authenticateEmployee',
      );
      throw AuthException('auth_error_internal');
    }
  }
}
