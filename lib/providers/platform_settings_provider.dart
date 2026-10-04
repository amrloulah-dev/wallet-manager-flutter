import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/di/service_locator.dart';
import '../core/state/safe_change_notifier.dart';
import '../core/errors/app_error_handler.dart';
import '../core/errors/error_severity.dart';
import '../data/services/local_storage_service.dart';
import '../data/models/platform_settings_model.dart';

class PlatformSettingsProvider extends SafeChangeNotifier {
  final LocalStorageService _storage;
  final FirebaseFirestore _firestore;

  PlatformSettingsModel _settings = const PlatformSettingsModel.defaults();
  bool _isInitialized = false;

  PlatformSettingsModel get settings => _settings;
  bool get isInitialized => _isInitialized;

  PlatformSettingsProvider({
    LocalStorageService? storage,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? sl<LocalStorageService>(),
        _firestore = firestore ?? sl<FirebaseFirestore>();

  /// Initializes the settings. Checks cached settings first and refreshes if stale (>24 hours).
  Future<void> initialize() async {
    final lastFetch = _storage.getPlatformSettingsFetchTime();
    final cachedJson = _storage.getPlatformSettingsJson();

    if (lastFetch == null || cachedJson == null) {
      if (kDebugMode) {
        debugPrint(
            '🔥 [PlatformSettingsProvider] No cache found. Fetching from Firestore.');
      }
      await _fetchFromFirestore();
      _isInitialized = true;
      return;
    }

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastFetch;
    final isStale = elapsed > const Duration(hours: 24).inMilliseconds;

    if (isStale) {
      if (kDebugMode) {
        debugPrint(
            '🔥 [PlatformSettingsProvider] Cache expired (>24h). Refreshing from Firestore.');
      }
      await _fetchFromFirestore();
    } else {
      if (kDebugMode) {
        debugPrint('🔥 [PlatformSettingsProvider] Loading from cache.');
      }
      try {
        final decoded = json.decode(cachedJson) as Map<String, dynamic>;
        _settings = PlatformSettingsModel.fromJson(decoded);
      } catch (e, stack) {
        await _storage.clearPlatformSettings();
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          severity: ErrorSeverity.low,
          operation: 'PlatformSettingsProvider.initialize.decodeCache',
        );
        // If decoding failed, fetch fresh
        await _fetchFromFirestore();
      }
    }
    _isInitialized = true;
  }

  /// Bypasses the 24-hour TTL check and forces a fresh fetch from Firestore.
  Future<void> forceRefresh() async {
    if (kDebugMode) {
      debugPrint('🔥 [PlatformSettingsProvider] Force refreshing settings.');
    }
    await _fetchFromFirestore();
  }

  /// Internal helper to fetch settings from Firestore, save to cache, and notify listeners.
  Future<void> _fetchFromFirestore() async {
    try {
      final doc = await _firestore.collection('settings').doc('global').get();
      if (doc.exists && doc.data() != null) {
        final model = PlatformSettingsModel.fromJson(doc.data()!);
        _settings = model;
        if (kDebugMode) {
          debugPrint(
              '🔥 [PlatformSettingsProvider] Parsed ${model.plans.length} plans successfully.');
        }
        await _storage.savePlatformSettings(json.encode(model.toJson()));
        safeNotify();
      } else {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Settings document settings/global does not exist',
        );
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.medium,
        operation: 'PlatformSettingsProvider._fetchFromFirestore',
      );
      // Fallback to cache if possible
      final cachedJson = _storage.getPlatformSettingsJson();
      if (cachedJson != null) {
        try {
          final decoded = json.decode(cachedJson) as Map<String, dynamic>;
          _settings = PlatformSettingsModel.fromJson(decoded);
        } catch (_) {
          await _storage.clearPlatformSettings();
          _settings = const PlatformSettingsModel.defaults();
        }
      } else {
        _settings = const PlatformSettingsModel.defaults();
      }
      safeNotify();
    }
  }
}
