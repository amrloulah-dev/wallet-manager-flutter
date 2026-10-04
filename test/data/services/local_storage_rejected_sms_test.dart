import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService Rejected SMS Diagnostics [TEMP DIAGNOSTIC]', () {
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

    test('getRejectedSmsLogs returns empty list when no logs exist', () {
      final logs = storage.getRejectedSmsLogs();
      expect(logs, isEmpty);
    });

    test('logRejectedSms logs entries with required payload schema', () async {
      await storage.logRejectedSms(
        sender: '01012345678',
        rawBody: 'Unparsable message body',
        reason: 'AMOUNT_NOT_FOUND',
        failureStep: 'REGEX_FAILED',
      );

      final logs = storage.getRejectedSmsLogs();
      expect(logs.length, 1);
      final log = logs.first;
      expect(log['sender'], '01012345678');
      expect(log['rawBody'], 'Unparsable message body');
      expect(log['reason'], 'AMOUNT_NOT_FOUND');
      expect(log['failureStep'], 'REGEX_FAILED');
      expect(log['timestamp'], isNotNull);
      expect(DateTime.tryParse(log['timestamp']), isNotNull);
    });

    test('logRejectedSms operates as a ring buffer of max 50 items (newest first)', () async {
      // Insert 55 items
      for (int i = 1; i <= 55; i++) {
        await storage.logRejectedSms(
          sender: 'Sender_$i',
          rawBody: 'Message_$i',
          reason: 'UNKNOWN_SENDER',
          failureStep: 'STEP_$i',
        );
      }

      final logs = storage.getRejectedSmsLogs();
      // Should cap at 50
      expect(logs.length, 50);

      // Newest should be at index 0 (Sender_55)
      expect(logs.first['sender'], 'Sender_55');
      // Oldest retained should be Sender_6 (1 to 5 dropped)
      expect(logs.last['sender'], 'Sender_6');
    });

    test('clearRejectedSmsLogs removes all logged entries', () async {
      await storage.logRejectedSms(
        sender: '01012345678',
        rawBody: 'Test body',
        reason: 'TYPE_UNRESOLVED',
      );
      expect(storage.getRejectedSmsLogs().length, 1);

      await storage.clearRejectedSmsLogs();
      expect(storage.getRejectedSmsLogs(), isEmpty);
    });
  });
}
