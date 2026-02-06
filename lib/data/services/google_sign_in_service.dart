import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    } catch (e) {
      rethrow;
    }
  }

  // ===========================
  // Sign Out
  // ===========================
  /// Signs the current user out from both Google and Firebase.
  /// Signs the current user out from both Google and Firebase.
  // ===========================
// Sign Out
// ===========================
  /// Signs the current user out from both Google and Firebase.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      // Error is propagated to be handled by the AuthProvider
      rethrow;
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
