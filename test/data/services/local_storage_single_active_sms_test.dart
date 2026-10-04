import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService Single-Item Active SMS Tests', () {
    late LocalStorageService storage;
    late MockFlutterSecureStorage mockSecureStorage;

    setUp(() async {
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
      expect(await storage.readCurrentActiveSms(), isNull);

      final payload = {
        'amount': 200.0,
        'sender': '01123456789',
        'type': 'deposit',
      };
      await storage.saveCurrentActiveSms(payload);

      final readData = await storage.readCurrentActiveSms();
      expect(readData, isNotNull);
      expect(readData?['amount'], 200.0);
      expect(readData?['sender'], '01123456789');
      expect(readData?['type'], 'deposit');
    });

    test('clearCurrentActiveSms deletes the key and subsequent read returns null', () async {
      final payload = {'amount': 300.0};
      await storage.saveCurrentActiveSms(payload);
      expect(await storage.readCurrentActiveSms(), isNotNull);

      await storage.clearCurrentActiveSms();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('current_active_sms'), isFalse);
      expect(await storage.readCurrentActiveSms(), isNull);
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
      expect((await storage.readCurrentActiveSms())?['amount'], 100.0);

      await storage.saveCurrentActiveSms(secondPayload);
      final active = await storage.readCurrentActiveSms();
      expect(active?['amount'], 500.0);
      expect(active?['sender'], '01000000002');
    });
  });
}
