import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageService storage;
  late MockFlutterSecureStorage mockSecureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSecureStorage = MockFlutterSecureStorage();
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'))).thenAnswer((_) async {});
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});

    LocalStorageService.reset();
    storage = LocalStorageService();
    await storage.initialize(secureStorage: mockSecureStorage);
  });

  group('LocalStorageService Single-Item Active SMS (current_active_sms)', () {
    test('should save and read active SMS data correctly', () async {
      final item = {'amount': 100.0, 'sender': '01011111111', 'type': 'credit'};

      await storage.saveCurrentActiveSms(item);

      final readData = storage.readCurrentActiveSms();
      expect(readData, isNotNull);
      expect(readData!['amount'], 100.0);
      expect(readData['sender'], '01011111111');
    });

    test('should overwrite active SMS completely when new SMS arrives (Single-Item / No Queue)', () async {
      await storage.saveCurrentActiveSms({'id': 1, 'amount': 10.0});
      await storage.saveCurrentActiveSms({'id': 2, 'amount': 20.0});

      final active = storage.readCurrentActiveSms();
      expect(active, isNotNull);
      expect(active!['id'], 2);
      expect(active['amount'], 20.0);
    });

    test('clearCurrentActiveSms should purge the active SMS', () async {
      await storage.saveCurrentActiveSms({'amount': 50.0});
      expect(storage.readCurrentActiveSms(), isNotNull);

      await storage.clearCurrentActiveSms();

      expect(storage.readCurrentActiveSms(), isNull);
    });
  });

  group('Completed Transaction IPC Sync Key Separation', () {
    test('saveCompletedTxSync should write to completed_tx_sync and not mutate active SMS', () async {
      final smsData = {'amount': 100.0, 'sender': '01000000000', 'type': 'credit'};
      await storage.saveCurrentActiveSms(smsData);

      final txSyncData = {
        'transactionId': 'tx_123',
        'amount': 100.0,
        'walletId': 'wallet_abc',
        'type': 'credit',
      };
      await storage.saveCompletedTxSync(txSyncData);

      // Active SMS must remain intact
      expect(storage.readCurrentActiveSms()?['amount'], 100.0);

      // Completed sync read should return the txSyncData
      final readTx = await storage.readCompletedTxSync();
      expect(readTx, isNotNull);
      expect(readTx!['transactionId'], 'tx_123');

      // Clearing completed sync must not clear the active SMS
      await storage.clearCompletedTxSync();
      expect(await storage.readCompletedTxSync(), isNull);
      expect(storage.readCurrentActiveSms()?['sender'], '01000000000');
    });
  });
}
