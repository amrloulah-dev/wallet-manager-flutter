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

  group('LocalStorageService FIFO Queue (pending_overlay_data)', () {
    test('should enqueue and dequeue items in FIFO order', () async {
      final item1 = {'amount': 100.0, 'sender': '01011111111', 'type': 'credit'};
      final item2 = {'amount': 250.0, 'sender': '01022222222', 'type': 'debit'};

      await storage.enqueueOverlayData(item1);
      await storage.enqueueOverlayData(item2);

      expect(await storage.getOverlayQueueLength(), 2);

      final dequeued1 = await storage.dequeueOverlayData();
      expect(dequeued1, isNotNull);
      expect(dequeued1!['amount'], 100.0);
      expect(dequeued1['sender'], '01011111111');

      expect(await storage.getOverlayQueueLength(), 1);

      final dequeued2 = await storage.dequeueOverlayData();
      expect(dequeued2, isNotNull);
      expect(dequeued2!['amount'], 250.0);
      expect(dequeued2['sender'], '01022222222');

      expect(await storage.getOverlayQueueLength(), 0);

      final dequeued3 = await storage.dequeueOverlayData();
      expect(dequeued3, isNull);
    });

    test('should cap queue at maximum 5 items and drop oldest on overflow', () async {
      for (int i = 1; i <= 6; i++) {
        await storage.enqueueOverlayData({'id': i, 'amount': i * 10.0});
      }

      expect(await storage.getOverlayQueueLength(), 5);

      // Oldest item (id: 1) should have been dropped; first dequeued should be id: 2
      final first = await storage.dequeueOverlayData();
      expect(first, isNotNull);
      expect(first!['id'], 2);
    });

    test('clearVault should drain the entire queue', () async {
      await storage.enqueueOverlayData({'amount': 50.0});
      await storage.enqueueOverlayData({'amount': 75.0});

      expect(await storage.getOverlayQueueLength(), 2);

      await storage.clearVault();

      expect(await storage.getOverlayQueueLength(), 0);
      expect(await storage.dequeueOverlayData(), isNull);
    });
  });

  group('Completed Transaction IPC Sync Key Separation', () {
    test('saveCompletedTxSync should write to completed_tx_sync and not mutate the SMS queue', () async {
      final smsData = {'amount': 100.0, 'sender': '01000000000', 'type': 'credit'};
      await storage.enqueueOverlayData(smsData);

      final txSyncData = {
        'transactionId': 'tx_123',
        'amount': 100.0,
        'walletId': 'wallet_abc',
        'type': 'credit',
      };
      await storage.saveCompletedTxSync(txSyncData);

      // SMS queue must remain intact with exactly 1 item
      expect(await storage.getOverlayQueueLength(), 1);

      // Completed sync read should return the txSyncData
      final readTx = await storage.readCompletedTxSync();
      expect(readTx, isNotNull);
      expect(readTx!['transactionId'], 'tx_123');

      // Clearing completed sync must not clear the SMS queue
      await storage.clearCompletedTxSync();
      expect(await storage.readCompletedTxSync(), isNull);
      expect(await storage.getOverlayQueueLength(), 1);

      final dequeuedSms = await storage.dequeueOverlayData();
      expect(dequeuedSms, isNotNull);
      expect(dequeuedSms!['sender'], '01000000000');
    });
  });
}
