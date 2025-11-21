import 'package:firebase_auth/firebase_auth.dart';
import '../../core/errors/app_exceptions.dart';
import '../services/firebase_service.dart';
import '../services/google_sign_in_service.dart';

/// A repository to handle all authentication-related operations.
class AuthRepository {
  final FirebaseService _firebaseService;
  final GoogleSignInService _googleSignInService;

  /// Constructor with optional dependency injection for testing.
  AuthRepository({
    FirebaseService? firebaseService,
    GoogleSignInService? googleSignInService,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _googleSignInService = googleSignInService ?? GoogleSignInService();

  /// Private getter for easy access to the FirebaseAuth instance.
  FirebaseAuth get _auth => _firebaseService.auth;

  // ===========================
  // Google Sign-In Methods
  // ===========================

  /// Signs in the user with their Google account.
  ///
  /// Throws a custom [AuthException] or a subclass for specific Firebase errors.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final userCredential = await _googleSignInService.signInWithGoogle();

      if (userCredential == null) {
        return null;
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'account-exists-with-different-credential':
          throw AuthException('هذا الحساب موجود بالفعل ولكن بطريقة تسجيل دخول مختلفة.');
        case 'invalid-credential':
          throw InvalidCredentialsException();
        case 'operation-not-allowed':
          throw AuthException('تسجيل الدخول باستخدام جوجل غير مفعل حاليًا.');
        case 'user-disabled':
          throw AuthException('تم تعطيل هذا الحساب.');
        case 'user-not-found':
          throw UserNotFoundException();
        default:
          throw AuthException('حدث خطأ غير معروف أثناء تسجيل الدخول: ${e.message}');
      }
    } catch (e) {
      throw AuthException('حدث خطأ أثناء تسجيل الدخول: ${e.toString()}');
    }
  }

  /// Signs out the current user from both Google and Firebase.
  Future<void> signOut() async {
    try {
      await _googleSignInService.signOut();
    } catch (e) {
      throw AuthException('حدث خطأ أثناء تسجيل الخروج: ${e.toString()}');
    }
  }

  // ===========================
  // User State Methods
  // ===========================

  /// Returns the current Firebase [User] object, or null if not signed in.
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// A stream that notifies about changes to the user's sign-in state.
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// Returns true if a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Returns the UID of the current user, or null if not signed in.
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // ===========================
  // User Info Methods
  // ===========================

  /// Returns the email of the current user.
  String? getUserEmail() {
    return _auth.currentUser?.email;
  }

  /// Returns the display name of the current user.
  String? getUserDisplayName() {
    return _auth.currentUser?.displayName;
  }

  /// Returns the photo URL of the current user.
  String? getUserPhotoURL() {
    return _auth.currentUser?.photoURL;
  }

  /// Reloads the current user\'s data from Firebase.
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      throw AuthException('فشل في تحديث بيانات المستخدم: \${e.toString()}');
    }
  }


  }
