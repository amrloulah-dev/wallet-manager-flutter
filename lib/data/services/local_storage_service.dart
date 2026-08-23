import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../core/enums/user_enums.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/error_severity.dart';
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
  FlutterSecureStorage? _secureStorage;

  // In-memory cache for sensitive data (to maintain sync access)
  String? _cachedUserId;
  String? _cachedStoreId;
  UserRole _cachedUserRole = UserRole.unknown;
  String? _cachedPepper;

  /// Resets the internal state for testing.
  @visibleForTesting
  static void reset() {
    _instance._prefs = null;
    _instance._secureStorage = null;
    _instance._cachedUserId = null;
    _instance._cachedStoreId = null;
    _instance._cachedUserRole = UserRole.unknown;
    _instance._cachedPepper = null;
  }

  // ===========================
  // Initialize
  // ===========================
  /// Initializes the SharedPreferences and SecureStorage instances.
  /// Must be called once at app startup.
  Future<void> initialize({FlutterSecureStorage? secureStorage}) async {
    if (_prefs != null && _secureStorage != null) {
      return;
    }
    _prefs ??= await SharedPreferences.getInstance();
    _secureStorage ??= secureStorage ??
        const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

    // ── Clean up orphans & Migrate (Phase 8.1 Unification) ──────────
    // 1. Remove the legacy 'pending_overlay_tx' key used by OverlayRepository
    if (_prefs!.containsKey('pending_overlay_tx')) {
      await _prefs!.remove('pending_overlay_tx');
    }

    // 2. Migrate 'languageCode' to 'app_locale' if needed
    const String oldLangKey = 'languageCode';
    const String newLocaleKey = 'app_locale';
    if (_prefs!.containsKey(oldLangKey)) {
      if (!_prefs!.containsKey(newLocaleKey)) {
        final String? code = _prefs!.getString(oldLangKey);
        if (code != null) {
          await _prefs!.setString(newLocaleKey, code);
        }
      }
      await _prefs!.remove(oldLangKey);
    }

    // ── SECURITY REMEDIATION (Phase 11) ──────────────────────────────
    // 1. Lazy migration of sensitive data to Secure Storage
    final List<String> sensitiveKeys = [_keyUserId, _keyStoreId, _keyUserRole];
    for (final key in sensitiveKeys) {
      if (_prefs!.containsKey(key)) {
        final String? value = _prefs!.getString(key);
        if (value != null) {
          await _secureStorage!.write(key: key, value: value);
        }
        await _prefs!.remove(key);
      }
    }

    // 2. Load into memory cache for sync access
    await _loadSecureCache();
  }

  /// Loads sensitive data from secure storage into memory cache.
  ///
  /// Applies the standard Android Keystore auto-recovery pattern:
  /// if the underlying cipher is corrupt (NullPointerException surfaced as a
  /// [PlatformException]), we wipe all broken keys with [deleteAll] and retry
  /// once so the app can boot cleanly. The user's session will be cleared,
  /// which is the accepted trade-off for this class of hardware failure.
  Future<void> _loadSecureCache() async {
    try {
      await _doLoadSecureCache();
    } on PlatformException catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ [SecureStorage] Keystore corrupted — wiping and retrying. '
            'Error: $e');
      }
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.medium,
        operation: 'LocalStorageService._loadSecureCache.recovery',
      );
      // Wipe all broken entries so the cipher can be reconstructed cleanly.
      await _secureStorage!.deleteAll();
      // Retry with a clean keystore — values will be null (no session).
      await _doLoadSecureCache();
    }
  }

  /// Inner implementation — performs the actual secure-storage reads.
  Future<void> _doLoadSecureCache() async {
    _cachedUserId = await _secureStorage!.read(key: _keyUserId);
    _cachedStoreId = await _secureStorage!.read(key: _keyStoreId);
    final roleStr = await _secureStorage!.read(key: _keyUserRole);
    _cachedUserRole =
        roleStr != null ? UserRole.fromString(roleStr) : UserRole.unknown;
    _cachedPepper = await _secureStorage!.read(key: _kSubPepper);
    if (_cachedPepper == null) {
      _cachedPepper = Uuid().v4();
      await _secureStorage!.write(key: _kSubPepper, value: _cachedPepper!);
    }
  }

  /// Throws an exception if the service is not initialized.
  void _ensureInitialized() {
    if (_prefs == null || _secureStorage == null) {
      throw Exception(
          'Local Storage not initialized. Call initialize() first.');
    }
  }

  /// Forces the plugin to reload data from disk.
  /// Crucial for isolates (like the Overlay) reading data written by the Main App.
  Future<void> reloadDisk() async {
    _ensureInitialized();
    await _prefs!.reload();
    await _loadSecureCache();
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
  static const String _kSubPepper = 'sub_integrity_pepper';

  // ===========================
  // Save Session
  // ===========================
  /// Saves the complete user session data to local storage.
  Future<void> saveSession({
    required String userId,
    required String storeId,
    required UserRole userRole,
    required String userName,
    required String storeName,
  }) async {
    _ensureInitialized();

    // Sensitive data to Secure Storage
    await _secureStorage!.write(key: _keyUserId, value: userId);
    await _secureStorage!.write(key: _keyStoreId, value: storeId);
    await _secureStorage!.write(key: _keyUserRole, value: userRole.name);

    // Update Cache
    _cachedUserId = userId;
    _cachedStoreId = storeId;
    _cachedUserRole = userRole;

    // Non-sensitive to SharedPreferences
    await _prefs!.setString(_keyUserName, userName);
    await _prefs!.setString(_keyStoreName, storeName);
  }

  // ===========================
  // Get Session Data
  // ===========================
  String? get userId => _cachedUserId;
  String? get storeId => _cachedStoreId;

  /// Returns the user role as an Enum. Fail-closed to unknown if not set or invalid.
  UserRole get userRole => _cachedUserRole;

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
    // Secure Storage
    await _secureStorage!.delete(key: _keyUserId);
    await _secureStorage!.delete(key: _keyStoreId);
    await _secureStorage!.delete(key: _keyUserRole);

    // Cache
    _cachedUserId = null;
    _cachedStoreId = null;
    _cachedUserRole = UserRole.unknown;

    // SharedPreferences
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
  // Language & Locale Handling
  // ===========================
  static const String _kLocale = 'app_locale';

  /// Saves the language code/locale.
  Future<void> saveLanguageCode(String code) async {
    _ensureInitialized();
    await _prefs!.setString(_kLocale, code);
  }

  /// Retrieves the saved language code, defaulting to 'ar'.
  String get languageCode => _prefs?.getString(_kLocale) ?? 'ar';

  /// Saves the app locale string (alias for saveLanguageCode).
  Future<void> saveLocale(String localeCode) => saveLanguageCode(localeCode);

  /// Retrieves the saved locale code, or null if not set.
  String? get savedLocale => _prefs?.getString(_kLocale);

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

  // Subscription background sync keys
  static const String _kSubEndDateMs = 'sub_end_date_ms';
  static const String _kIsSubLifetime = 'is_sub_lifetime';
  static const String _kSubSmsEnabled = 'sub_sms_enabled';
  static const String _kSubIsSuspended = 'sub_is_suspended';
  static const String _kSubChecksum = 'sub_checksum';

  /// Syncs subscription limits to SharedPreferences with HMAC integrity check (Report 2: M-7).
  Future<void> saveSubscriptionLimits({
    required int? endDateMs,
    required bool isLifetime,
    required bool smsEnabled,
    required bool isSuspended,
  }) async {
    _ensureInitialized();
    if (endDateMs != null) {
      await _prefs!.setInt(_kSubEndDateMs, endDateMs);
    } else {
      await _prefs!.remove(_kSubEndDateMs);
    }
    await _prefs!.setBool(_kIsSubLifetime, isLifetime);
    await _prefs!.setBool(_kSubSmsEnabled, smsEnabled);
    await _prefs!.setBool(_kSubIsSuspended, isSuspended);

    // Generate and save checksum (Report 2: M-7)
    final checksum = _generateSubChecksum(
      endDateMs: endDateMs,
      isLifetime: isLifetime,
      smsEnabled: smsEnabled,
      isSuspended: isSuspended,
    );
    await _prefs!.setString(_kSubChecksum, checksum);
  }

  String _generateSubChecksum({
    int? endDateMs,
    required bool isLifetime,
    required bool smsEnabled,
    required bool isSuspended,
  }) {
    final data = '$endDateMs|$isLifetime|$smsEnabled|$isSuspended';
    // Use dynamic pepper from Secure Storage (Phase 11 Remediation)
    final key = utf8.encode(_cachedPepper ?? '');
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    return hmac.convert(bytes).toString();
  }

  /// Returns true if the subscription limits have not been tampered with.
  bool get isSubIntegrityValid {
    final storedChecksum = _prefs?.getString(_kSubChecksum);
    if (storedChecksum == null) return false;

    final currentChecksum = _generateSubChecksum(
      endDateMs: _prefs?.getInt(_kSubEndDateMs),
      isLifetime: _prefs?.getBool(_kIsSubLifetime) ?? false,
      smsEnabled: _prefs?.getBool(_kSubSmsEnabled) ?? false,
      isSuspended: _prefs?.getBool(_kSubIsSuspended) ?? false,
    );

    return storedChecksum == currentChecksum;
  }

  int? get subEndDateMs => _prefs?.getInt(_kSubEndDateMs);

  bool get isSubLifetime {
    if (!isSubIntegrityValid) return false;
    return _prefs?.getBool(_kIsSubLifetime) ?? false;
  }

  bool get subSmsEnabled {
    if (!isSubIntegrityValid) return false;
    return _prefs?.getBool(_kSubSmsEnabled) ?? false;
  }

  bool get subIsSuspended {
    if (!isSubIntegrityValid) return true; // Fail-secure
    return _prefs?.getBool(_kSubIsSuspended) ?? false;
  }

  // Subscription sync timestamp for 24h TTL check
  static const String _kSubLastSyncMs = 'sub_last_sync_ms';

  /// Persists the current timestamp as the last subscription sync time.
  Future<void> saveSubLastSyncMs() async {
    _ensureInitialized();
    await _prefs!
        .setInt(_kSubLastSyncMs, DateTime.now().millisecondsSinceEpoch);
  }

  /// Returns the last subscription sync timestamp in milliseconds, or null.
  int? get subLastSyncMs => _prefs?.getInt(_kSubLastSyncMs);

  /// Returns true if the subscription data was synced within the last 24 hours.
  bool get isSubscriptionSyncFresh {
    final lastSync = subLastSyncMs;
    if (lastSync == null) return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastSync;
    return elapsed < const Duration(hours: 24).inMilliseconds;
  }

  // Subscription UI states
  static const String _kHasSeenSuccessModal = 'has_seen_success_modal';
  static const String _kHasDismissedRejection = 'has_dismissed_rejection';
  static const String _kLastSeenPaymentKey = 'last_seen_payment_key';

  Future<void> setHasSeenSuccessModal(bool seen) async {
    _ensureInitialized();
    await _prefs!.setBool(_kHasSeenSuccessModal, seen);
  }

  bool get hasSeenSuccessModal =>
      _prefs?.getBool(_kHasSeenSuccessModal) ?? false;

  Future<void> setLastSeenPaymentKey(String key) async {
    _ensureInitialized();
    await _prefs!.setString(_kLastSeenPaymentKey, key);
  }

  String? get lastSeenPaymentKey => _prefs?.getString(_kLastSeenPaymentKey);

  Future<void> setHasDismissedRejection(bool dismissed) async {
    _ensureInitialized();
    await _prefs!.setBool(_kHasDismissedRejection, dismissed);
  }

  bool get hasDismissedRejection =>
      _prefs?.getBool(_kHasDismissedRejection) ?? false;

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
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
        'Failed to find wallet for SIM slot $simSlotIndex: $e',
        'LocalStorageService.getWalletForSim',
        stackTrace: stack,
      );
      return null;
    }
  }

  // ===========================
  // SMS Deduplication (Idempotency Cache)
  // ===========================
  static const String _kRecentSmsFingerprints = 'recent_sms_fingerprints';
  static const int _kMaxSmsFingerprints = 10;

  /// Checks if the SMS fingerprint has already been processed within the recent cache.
  /// Calls [reloadDisk] to ensure cross-isolate multi-process synchronization.
  Future<bool> isSmsProcessed(String fingerprint) async {
    _ensureInitialized();
    await reloadDisk();
    final List<String> fingerprints =
        _prefs?.getStringList(_kRecentSmsFingerprints) ?? [];
    return fingerprints.contains(fingerprint);
  }

  /// Caches a processed SMS fingerprint, enforcing a max FIFO capacity of 10 items.
  Future<void> cacheSmsFingerprint(String fingerprint) async {
    _ensureInitialized();
    await reloadDisk();
    final List<String> fingerprints =
        _prefs!.getStringList(_kRecentSmsFingerprints) ?? [];

    if (!fingerprints.contains(fingerprint)) {
      fingerprints.add(fingerprint);
      while (fingerprints.length > _kMaxSmsFingerprints) {
        fingerprints.removeAt(0); // Evict oldest (FIFO)
      }
      await _prefs!.setStringList(_kRecentSmsFingerprints, fingerprints);
    }
  }

  /// Retrieves the list of currently cached SMS fingerprints.
  Future<List<String>> getRecentSmsFingerprints() async {
    _ensureInitialized();
    await reloadDisk();
    return _prefs?.getStringList(_kRecentSmsFingerprints) ?? [];
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
        'phoneNumber': w.phoneNumber,
        'type': w.walletType.name,
        'walletType': w.walletType.name,
        'isFrozen': w.isFrozen,
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
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'LocalStorageService.getCachedWalletLiteList',
      );
      return [];
    }
  }

  // ===========================
  // Current Active SMS (Single-Item / Instant-Kill)
  // ===========================
  static const String _kCurrentActiveSms = 'current_active_sms';

  /// Saves the current active SMS transaction data, overwriting any previous entry.
  Future<void> saveCurrentActiveSms(Map<String, dynamic> data) async {
    _ensureInitialized();
    await _prefs!.setString(_kCurrentActiveSms, json.encode(data));
  }

  /// Reads the current active SMS transaction data synchronously.
  Map<String, dynamic>? readCurrentActiveSms() {
    final String? raw = _prefs?.getString(_kCurrentActiveSms);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'LocalStorageService.readCurrentActiveSms',
      );
    }
    return null;
  }

  /// Instantly deletes the current active SMS transaction data.
  Future<void> clearCurrentActiveSms() async {
    if (_prefs == null) {
      await initialize();
    }
    await _prefs?.remove(_kCurrentActiveSms);
  }

  // ===========================
  // Vault Queue (Background → Overlay Data Bridge)
  // ===========================
  static const String _kPendingOverlayData = 'pending_overlay_data';
  static const String _kCompletedTxSync = 'completed_tx_sync';
  static const String _kPersistentDeviceId = 'persistent_device_id';
  static const int _kMaxOverlayQueueSize = 5;

  /// Appends incoming parsed SMS transaction data to the FIFO queue.
  /// Drops the oldest item if the queue exceeds [_kMaxOverlayQueueSize] (5).
  Future<void> enqueueOverlayData(Map<String, dynamic> data) async {
    _ensureInitialized();
    await reloadDisk();

    List<Map<String, dynamic>> queue = [];
    final String? raw = _prefs?.getString(_kPendingOverlayData);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          queue = decoded
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else if (decoded is Map) {
          // Migration/fallback if a legacy single object was present
          queue.add(Map<String, dynamic>.from(decoded));
        }
      } catch (e, stack) {
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          severity: ErrorSeverity.low,
          operation: 'LocalStorageService.enqueueOverlayData_decode',
        );
      }
    }

    queue.add(data);

    // Enforce max capacity by evicting oldest (head) items
    while (queue.length > _kMaxOverlayQueueSize) {
      queue.removeAt(0);
    }

    await _prefs!.setString(_kPendingOverlayData, json.encode(queue));
  }

  /// Dequeues and returns the first (oldest) pending transaction in FIFO order.
  /// Removes it from disk immediately upon consumption.
  Future<Map<String, dynamic>?> dequeueOverlayData() async {
    if (_prefs == null) {
      await initialize();
    }
    await reloadDisk();

    final String? raw = _prefs?.getString(_kPendingOverlayData);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        final queue = decoded
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        if (queue.isEmpty) {
          await _prefs!.remove(_kPendingOverlayData);
          return null;
        }

        final first = queue.removeAt(0);

        if (queue.isEmpty) {
          await _prefs!.remove(_kPendingOverlayData);
        } else {
          await _prefs!.setString(_kPendingOverlayData, json.encode(queue));
        }

        return first;
      } else if (decoded is Map) {
        // Legacy single object: consume and remove
        await _prefs!.remove(_kPendingOverlayData);
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'LocalStorageService.dequeueOverlayData',
      );
    }
    return null;
  }

  /// Returns the current number of queued SMS payloads pending display in the overlay.
  Future<int> getOverlayQueueLength() async {
    if (_prefs == null) {
      await initialize();
    }
    await reloadDisk();

    final String? raw = _prefs?.getString(_kPendingOverlayData);
    if (raw == null || raw.isEmpty) return 0;

    try {
      final decoded = json.decode(raw);
      if (decoded is List) {
        return decoded.length;
      } else if (decoded is Map) {
        return 1;
      }
    } catch (_) {}
    return 0;
  }

  /// Peeks at the next item in the FIFO queue without removing it.
  Future<Map<String, dynamic>?> peekOverlayData() async {
    if (_prefs == null) {
      await initialize();
    }
    await reloadDisk();

    final String? raw = _prefs?.getString(_kPendingOverlayData);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = json.decode(raw);
      if (decoded is List && decoded.isNotEmpty) {
        return Map<String, dynamic>.from(decoded.first);
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Saves transaction data from the background isolate (delegates to queue).
  Future<void> saveToVault(Map<String, dynamic> data) async {
    await enqueueOverlayData(data);
  }

  /// Reads the pending transaction written by the background service (delegates to dequeue).
  Future<Map<String, dynamic>?> readFromVault() async {
    return dequeueOverlayData();
  }

  /// Clears the entire SMS pending overlay vault queue.
  Future<void> clearVault() async {
    if (_prefs == null) {
      await initialize();
    }
    await _prefs?.remove(_kPendingOverlayData);
  }

  // ===========================
  // Completed Transaction IPC Sync (Overlay -> Main App)
  // ===========================

  /// Saves a completed transaction payload submitted by the overlay
  /// for the Main App's GlobalOverlayListener to ingest into memory.
  Future<void> saveCompletedTxSync(Map<String, dynamic> txData) async {
    _ensureInitialized();
    await _prefs!.setString(_kCompletedTxSync, json.encode(txData));
  }

  /// Reads the completed transaction sync payload for the Main App.
  Future<Map<String, dynamic>?> readCompletedTxSync() async {
    if (_prefs == null) {
      await initialize();
    }
    await reloadDisk();
    final String? raw = _prefs?.getString(_kCompletedTxSync);
    if (raw == null || raw.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  /// Clears the completed transaction sync key after the Main App has consumed it.
  Future<void> clearCompletedTxSync() async {
    if (_prefs == null) {
      await initialize();
    }
    await _prefs?.remove(_kCompletedTxSync);
  }

  // ===========================
  // Persistent Device ID
  // ===========================

  /// Saves a persistent device ID (UUID fallback).
  Future<void> savePersistentDeviceId(String deviceId) async {
    _ensureInitialized();
    await _prefs!.setString(_kPersistentDeviceId, deviceId);
  }

  /// Retrieves the saved persistent device ID.
  String? get persistentDeviceId => _prefs?.getString(_kPersistentDeviceId);

  // ===========================
  // Platform Settings Cache
  // ===========================
  static const String _kPlatformSettingsJson = 'platform_settings_json';
  static const String _kPlatformSettingsFetchTime =
      'platform_settings_fetch_time';

  /// Saves the serialized PlatformSettingsModel JSON to local storage and updates the fetch timestamp.
  Future<void> savePlatformSettings(String jsonStr) async {
    _ensureInitialized();
    await _prefs!.setString(_kPlatformSettingsJson, jsonStr);
    await _prefs!.setInt(
        _kPlatformSettingsFetchTime, DateTime.now().millisecondsSinceEpoch);
  }

  /// Retrieves the cached PlatformSettingsModel JSON, if any.
  String? getPlatformSettingsJson() {
    return _prefs?.getString(_kPlatformSettingsJson);
  }

  /// Retrieves the timestamp when the settings were last fetched.
  int? getPlatformSettingsFetchTime() {
    return _prefs?.getInt(_kPlatformSettingsFetchTime);
  }

  /// Clears the cached PlatformSettingsModel JSON and fetch timestamp.
  Future<void> clearPlatformSettings() async {
    _ensureInitialized();
    await _prefs!.remove(_kPlatformSettingsJson);
    await _prefs!.remove(_kPlatformSettingsFetchTime);
  }
}
