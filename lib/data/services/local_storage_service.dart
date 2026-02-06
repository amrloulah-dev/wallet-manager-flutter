import 'package:shared_preferences/shared_preferences.dart';

/// A singleton service to manage local data using SharedPreferences.
class LocalStorageService {
  // ===========================
  // Singleton Pattern
  // ===========================
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  // ===========================
  // Initialize
  // ===========================
  /// Initializes the SharedPreferences instance.
  /// Must be called once at app startup.
  Future<void> initialize() async {
    if (_prefs != null) {
      return;
    }
    _prefs = await SharedPreferences.getInstance();
  }

  /// Throws an exception if the service is not initialized.
  void _ensureInitialized() {
    if (_prefs == null) {
      throw Exception(
          'Local Storage not initialized. Call initialize() first.');
    }
  }

  // ===========================
  // Keys
  // ===========================
  static const String _keyUserId = 'userId';
  static const String _keyStoreId = 'storeId';
  static const String _keyUserRole = 'userRole';
  static const String _keyUserName = 'userName';
  static const String _keyStoreName = 'storeName';
  static const String _keyThemeMode = 'themeMode';

  // ===========================
  // Save Session
  // ===========================
  /// Saves the complete user session data to local storage.
  Future<void> saveSession({
    required String userId,
    required String storeId,
    required String userRole,
    required String userName,
    required String storeName,
  }) async {
    _ensureInitialized();
    await _prefs!.setString(_keyUserId, userId);
    await _prefs!.setString(_keyStoreId, storeId);
    await _prefs!.setString(_keyUserRole, userRole);
    await _prefs!.setString(_keyUserName, userName);
    await _prefs!.setString(_keyStoreName, storeName);
  }

  // ===========================
  // Get Session Data
  // ===========================
  String? get userId => _prefs?.getString(_keyUserId);
  String? get storeId => _prefs?.getString(_keyStoreId);
  String? get userRole => _prefs?.getString(_keyUserRole);
  String? get userName => _prefs?.getString(_keyUserName);
  String? get storeName => _prefs?.getString(_keyStoreName);

  // ===========================
  // Check if Session Exists
  // ===========================
  /// Returns true if essential session data (userId, storeId) exists.
  bool get hasSession => userId != null && storeId != null;

  // ===========================
  // Clear Session
  // ===========================
  /// Clears all user session-related data from local storage.
  Future<void> clearSession() async {
    _ensureInitialized();
    await _prefs!.remove(_keyUserId);
    await _prefs!.remove(_keyStoreId);
    await _prefs!.remove(_keyUserRole);
    await _prefs!.remove(_keyUserName);
    await _prefs!.remove(_keyStoreName);
  }

  // ===========================
  // Theme Mode Handling
  // ===========================
  /// Saves the selected theme mode ('light', 'dark', or 'system').
  Future<void> saveThemeMode(String mode) async {
    _ensureInitialized();
    await _prefs!.setString(_keyThemeMode, mode);
  }

  /// Retrieves the saved theme mode, defaulting to 'system'.
  String get themeMode => _prefs?.getString(_keyThemeMode) ?? 'system';

  // ===========================
  // Clear All Data
  // ===========================
  /// Clears all data from SharedPreferences.
  /// Use with caution.
  Future<void> clearAll() async {
    _ensureInitialized();
    await _prefs!.clear();
  }
}
