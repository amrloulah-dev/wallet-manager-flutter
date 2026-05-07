import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService Key Unification Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      LocalStorageService.reset();
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService.instance;
      await storage.initialize();
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
      await storage.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('languageCode'), isFalse);
      expect(prefs.containsKey('app_locale'), isTrue);
      expect(storage.languageCode, 'en');
    });

    test('should clean up pending_overlay_tx on initialization', () async {
      LocalStorageService.reset();
      SharedPreferences.setMockInitialValues({'pending_overlay_tx': 'stale'});

      storage = LocalStorageService.instance;
      await storage.initialize();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_overlay_tx'), isFalse);
    });
  });
}
