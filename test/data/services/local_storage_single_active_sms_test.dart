import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService Single-Item Active SMS Tests', () {
    late LocalStorageService storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService.instance;
      await storage.initialize();
    });

    tearDown(() {
      LocalStorageService.reset();
    });

    test('saveCurrentActiveSms writes JSON payload to current_active_sms key', () async {
      final payload = {
        'amount': 150.0,
        'sender': '01012345678',
        'type': 'transfer',
      };

      await storage.saveCurrentActiveSms(payload);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('current_active_sms'), isTrue);
      expect(prefs.getString('current_active_sms'), contains('"amount":150.0'));
      expect(prefs.getString('current_active_sms'), contains('"sender":"01012345678"'));
    });

    test('readCurrentActiveSms returns decoded Map or null when empty', () async {
      expect(storage.readCurrentActiveSms(), isNull);

      final payload = {
        'amount': 200.0,
        'sender': '01123456789',
        'type': 'deposit',
      };
      await storage.saveCurrentActiveSms(payload);

      final readData = storage.readCurrentActiveSms();
      expect(readData, isNotNull);
      expect(readData?['amount'], 200.0);
      expect(readData?['sender'], '01123456789');
      expect(readData?['type'], 'deposit');
    });

    test('clearCurrentActiveSms deletes the key and subsequent read returns null', () async {
      final payload = {'amount': 300.0};
      await storage.saveCurrentActiveSms(payload);
      expect(storage.readCurrentActiveSms(), isNotNull);

      await storage.clearCurrentActiveSms();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('current_active_sms'), isFalse);
      expect(storage.readCurrentActiveSms(), isNull);
    });

    test('saveCurrentActiveSms overwrites previous payload completely (Single-Item / No Queue)', () async {
      final firstPayload = {
        'amount': 100.0,
        'sender': '01000000001',
      };
      final secondPayload = {
        'amount': 500.0,
        'sender': '01000000002',
      };

      await storage.saveCurrentActiveSms(firstPayload);
      expect(storage.readCurrentActiveSms()?['amount'], 100.0);

      await storage.saveCurrentActiveSms(secondPayload);
      final active = storage.readCurrentActiveSms();
      expect(active?['amount'], 500.0);
      expect(active?['sender'], '01000000002');
    });
  });
}
