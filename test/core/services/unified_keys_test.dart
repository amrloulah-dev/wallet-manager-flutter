import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService Key Unification Tests', () {
    late LocalStorageService storage;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() async {
      LocalStorageService.reset();
      SharedPreferences.setMockInitialValues({});

      mockSecureStorage = MockFlutterSecureStorage();
      when(() => mockSecureStorage.read(key: any(named: 'key')))
          .thenAnswer((_) async => null);
      when(() => mockSecureStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          )).thenAnswer((_) async => {});

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);
    });

    test('should save and read from unified vault key', () async {
      final data = {'amount': 100.0, 'sender': '123'};
      await storage.saveToVault(data);

      final prefs = await SharedPreferences.getInstance();
      // Verify it uses the correct key
      expect(prefs.containsKey('pending_overlay_data'), isTrue);

      final readData = storage.readFromVault();
      expect(readData?['amount'], 100.0);
    });

    test('should not use orphan key pending_overlay_tx', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_overlay_tx', 'stale_data');

      // storage.readFromVault() should NOT read from pending_overlay_tx
      expect(storage.readFromVault(), isNull);
    });

    test('should migrate languageCode to app_locale on initialization',
        () async {
      LocalStorageService.reset();
      // Pre-populate with old key
      SharedPreferences.setMockInitialValues({'languageCode': 'en'});

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('languageCode'), isFalse);
      expect(prefs.containsKey('app_locale'), isTrue);
      expect(storage.languageCode, 'en');
    });

    test('should clean up pending_overlay_tx on initialization', () async {
      LocalStorageService.reset();
      SharedPreferences.setMockInitialValues({'pending_overlay_tx': 'stale'});

      storage = LocalStorageService.instance;
      await storage.initialize(secureStorage: mockSecureStorage);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_overlay_tx'), isFalse);
    });

    test('should clear platform settings from cache', () async {
      await storage.savePlatformSettings('{"limits": {}}');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('platform_settings_json'), isTrue);
      expect(prefs.containsKey('platform_settings_fetch_time'), isTrue);

      await storage.clearPlatformSettings();

      expect(prefs.containsKey('platform_settings_json'), isFalse);
      expect(prefs.containsKey('platform_settings_fetch_time'), isFalse);
    });
  });
}
