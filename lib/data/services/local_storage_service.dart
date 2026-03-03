import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sim_wallet_config.dart';
import '../models/wallet_model.dart';

/// A singleton service to manage local data using SharedPreferences.
class LocalStorageService {
  // ===========================
  // Singleton Pattern
  // ===========================
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  static LocalStorageService get instance => _instance;

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

  /// Returns true if the saved theme mode is 'dark'
  bool get isDarkMode => themeMode == 'dark';

  // ===========================
  // Language Handling
  // ===========================
  static const String _keyLanguageCode = 'languageCode';

  /// Saves the language code
  Future<void> saveLanguageCode(String code) async {
    _ensureInitialized();
    await _prefs!.setString(_keyLanguageCode, code);
  }

  /// Retrieves the saved language code, defaulting to 'ar'
  String get languageCode => _prefs?.getString(_keyLanguageCode) ?? 'ar';

  // ===========================
  // Clear All Data
  // ===========================
  /// Clears all data from SharedPreferences.
  /// Use with caution.
  Future<void> clearAll() async {
    _ensureInitialized();
    await _prefs!.clear();
  }

  // ===========================
  // SMS Automation & SIM Linking
  // ===========================
  static const String _kSmsAutomationEnabled = 'sms_automation_enabled';
  static const String _kSimMappings = 'sim_wallet_mappings';

  /// Sets whether SMS automation is enabled.
  Future<void> setSmsAutomationEnabled(bool enabled) async {
    _ensureInitialized();
    await _prefs!.setBool(_kSmsAutomationEnabled, enabled);
  }

  /// Returns true if SMS automation is enabled (defaults to false).
  bool get isSmsAutomationEnabled =>
      _prefs?.getBool(_kSmsAutomationEnabled) ?? false;

  /// Saves the list of SIM-to-Wallet mappings.
  Future<void> saveSimMappings(List<SimWalletConfig> mappings) async {
    _ensureInitialized();
    final List<String> jsonList =
        mappings.map((config) => config.toJson()).toList();
    await _prefs!.setStringList(_kSimMappings, jsonList);
  }

  /// Retrieves the list of SIM-to-Wallet mappings.
  /// Returns an empty list if no data is found.
  List<SimWalletConfig> getSimMappings() {
    final List<String>? jsonList = _prefs?.getStringList(_kSimMappings);
    if (jsonList == null) {
      return [];
    }
    return jsonList
        .map((jsonStr) => SimWalletConfig.fromJson(jsonStr))
        .toList();
  }

  /// Helper to find the wallet configuration for a specific SIM slot index.
  SimWalletConfig? getWalletForSim(int simSlotIndex) {
    final mappings = getSimMappings();
    try {
      return mappings.firstWhere(
        (config) => config.simSlotIndex == simSlotIndex,
      );
    } catch (e) {
      return null;
    }
  }

  // ===========================
  // Wallet Lite Cache (For Overlay)
  // ===========================
  static const String _kWalletLiteCache = 'wallet_lite_cache';

  /// Caches a simplified list of wallets for the overlay to use.
  Future<void> cacheWalletLiteList(List<WalletModel> wallets) async {
    _ensureInitialized();
    final List<Map<String, dynamic>> liteList = wallets.map((w) {
      return {
        'id': w.walletId,
        'name': w.phoneNumber,
        'phone': w.phoneNumber,
        'type': w.walletType,
      };
    }).toList();

    final String jsonString = json.encode(liteList);
    await _prefs!.setString(_kWalletLiteCache, jsonString);
  }

  /// Retrieves the cached lite wallet list.
  List<Map<String, dynamic>> getCachedWalletLiteList() {
    final String? jsonString = _prefs?.getString(_kWalletLiteCache);
    if (jsonString == null) {
      return [];
    }
    try {
      final List<dynamic> decoded = json.decode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }
}
