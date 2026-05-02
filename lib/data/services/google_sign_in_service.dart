import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

/// A singleton service to handle Google Sign-In and Firebase authentication.
class GoogleSignInService {
  // ===========================
  // Singleton Pattern
  // ===========================
  static final GoogleSignInService _instance = GoogleSignInService._internal();
  factory GoogleSignInService() => _instance;
  GoogleSignInService._internal();

  // ===========================
  // Google & Firebase Instances
  // ===========================
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  final FirebaseAuth _auth = sl<FirebaseAuth>();

  // ===========================
  // Sign In with Google
  // ===========================
  /// Initiates the Google Sign-In flow and authenticates with Firebase.
  ///
  /// Returns a [UserCredential] on success.
  /// Throws an exception if the user cancels the sign-in process or if an error occurs.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // 1. Trigger the Google authentication flow.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If the user cancels the sign-in, googleUser will be null.
      if (googleUser == null) {
        return null;
      }

      // 2. Obtain the auth details from the request.
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 3. Create a new Firebase credential.
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Once signed in, return the UserCredential from Firebase.
      final userCredential = await _auth.signInWithCredential(credential);

      return userCredential;
    } on FirebaseAuthException catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'GoogleSignInService.signInWithGoogle',
      );
      throw AuthException('فشل تسجيل الدخول باستخدام جوجل: ${e.message}', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'GoogleSignInService.signInWithGoogle',
      );
      if (e is AppException) rethrow;
      throw AuthException('حدث خطأ غير متوقع أثناء تسجيل الدخول.');
    }
  }

  // ===========================
  // Sign Out
  // ===========================
  /// Signs the current user out from both Google and Firebase.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'GoogleSignInService.signOut',
      );
      throw AuthException('فشل تسجيل الخروج: ${e.message}', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'GoogleSignInService.signOut',
      );
      throw AuthException('حدث خطأ غير متوقع أثناء تسجيل الخروج.');
    }
  }

  // ===========================
  // Get Current User
  // ===========================
  /// Returns the current Firebase user, or null if not signed in.
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // ===========================
  // Check if Signed In
  // ===========================
  /// A quick getter to check if a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  // ===========================
  // Auth State Changes Stream
  // ===========================
  /// A stream that notifies about changes to the user's sign-in state.
  ///
  /// Use this in the UI to react to sign-in and sign-out events.
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
