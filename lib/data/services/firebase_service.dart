import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// A singleton service class to initialize and provide Firebase services.
class FirebaseService {
  // ===========================
  // Singleton Pattern
  // ===========================

  // Internal, private constructor.
  FirebaseService._internal();

  // The static, final instance of the service.
  static final FirebaseService _instance = FirebaseService._internal();

  // Factory constructor to return the singleton instance.
  factory FirebaseService() => _instance;

  // ===========================
  // Firebase Instances
  // ===========================

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;

  // ===========================
  // Getters
  // ===========================

  /// Provides access to the [FirebaseAuth] instance.
  /// Throws an exception if Firebase has not been initialized.
  FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception(
          'Firebase Auth not initialized. Call FirebaseService().initialize() first.');
    }
    return _auth!;
  }

  /// Provides access to the [FirebaseFirestore] instance.
  /// Throws an exception if Firebase has not been initialized.
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception(
          'Firestore not initialized. Call FirebaseService().initialize() first.');
    }
    return _firestore!;
  }

  /// Checks if the Firebase services have been initialized.
  bool get isInitialized => _auth != null && _firestore != null;

  // ===========================
  // Initialize Firebase
  // ===========================

  /// Initializes the Firebase app and configures services.
  /// This method should be called once in `main.dart` before `runApp()`.
  Future<void> initialize() async {
    // Prevent re-initialization.
    if (isInitialized) {
      return;
    }

    try {
      // Initialize the Firebase app.
      await Firebase.initializeApp();

      // Get instances of Firebase services.
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;

      // Configure Firestore settings for offline persistence and cache size.
      _firestore!.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      // Log the error and rethrow to allow for handling at the app's root.
      rethrow;
    }
  }

  /// Initializes the service with a mock or fake Firestore instance for testing.
  @visibleForTesting
  void initializeForTest(FirebaseFirestore firestore) {
    _firestore = firestore;
    // We don't initialize FirebaseAuth here as it's not needed for these tests.
    // If it were, we would use a mock instance.
  }
}
