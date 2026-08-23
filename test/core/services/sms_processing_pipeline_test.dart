import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

class FakeInitializationSettings extends Fake
    implements InitializationSettings {}

class FakeNotificationDetails extends Fake implements NotificationDetails {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeInitializationSettings());
    registerFallbackValue(FakeNotificationDetails());
  });

  group('LocalStorageService SMS Deduplication Cache', () {
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

    test('isSmsProcessed returns false initially and true after caching', () async {
      const fingerprint = 'Vodafone_تم تحويل مبلغ 100 جنيه_29812345';

      expect(await storage.isSmsProcessed(fingerprint), isFalse);

      await storage.cacheSmsFingerprint(fingerprint);

      expect(await storage.isSmsProcessed(fingerprint), isTrue);
    });

    test('cacheSmsFingerprint enforces max capacity of 10 items in FIFO order', () async {
      for (int i = 1; i <= 12; i++) {
        await storage.cacheSmsFingerprint('fingerprint_$i');
      }

      final recent = await storage.getRecentSmsFingerprints();
      expect(recent.length, 10);
      // Items 1 and 2 should have been evicted
      expect(recent.contains('fingerprint_1'), isFalse);
      expect(recent.contains('fingerprint_2'), isFalse);
      // Items 3 to 12 should be present
      expect(recent.first, 'fingerprint_3');
      expect(recent.last, 'fingerprint_12');
    });

    test('does not add duplicate fingerprints to the list', () async {
      await storage.cacheSmsFingerprint('fp_1');
      await storage.cacheSmsFingerprint('fp_1');

      final recent = await storage.getRecentSmsFingerprints();
      expect(recent.length, 1);
      expect(recent.first, 'fp_1');
    });
  });

  group('SmsProcessingPipeline Gate 0 & SIM Decoupling', () {
    late MockLocalStorageService mockStorage;
    late MockFlutterLocalNotificationsPlugin mockNotifications;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockStorage = MockLocalStorageService();
      mockNotifications = MockFlutterLocalNotificationsPlugin();

      setNotificationsPlugin(mockNotifications);

      when(() => mockStorage.isSmsAutomationEnabled).thenReturn(true);
      when(() => mockStorage.subIsSuspended).thenReturn(false);
      when(() => mockStorage.subSmsEnabled).thenReturn(true);
      when(() => mockStorage.isSubLifetime).thenReturn(true);
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(true);
      when(() => mockStorage.enqueueOverlayData(any())).thenAnswer((_) async {});
      when(() => mockNotifications.initialize(any())).thenAnswer((_) async => true);
      when(() => mockNotifications.show(any(), any(), any(), any())).thenAnswer((_) async {});

      const channel = MethodChannel('x-slayer/overlay_channel');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'checkPermission') return true;
        if (methodCall.method == 'isPermissionGranted') return true;
        if (methodCall.method == 'isActive') return false;
        if (methodCall.method == 'showOverlay') return true;
        if (methodCall.method == 'shareData') return true;
        return null;
      });
    });

    test('handleIncomingSms silently drops duplicate SMS when isSmsProcessed is true', () async {
      final nowMs = DateTime(2026, 8, 23, 6, 30).millisecondsSinceEpoch;
      final message = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': nowMs.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      final expectedFingerprint = 'VF-Cash_تم استلام مبلغ 500 جنيه من رقم 01012345678_${nowMs ~/ 60000}';

      // Simulate already processed in Gate 0
      when(() => mockStorage.isSmsProcessed(expectedFingerprint)).thenAnswer((_) async => true);

      await handleIncomingSms(message, mockStorage);

      // Verify Gate 0 immediately dropped the message without caching or enqueuing
      verify(() => mockStorage.isSmsProcessed(expectedFingerprint)).called(1);
      verifyNever(() => mockStorage.cacheSmsFingerprint(any()));
      verifyNever(() => mockStorage.enqueueOverlayData(any()));
      verifyNever(() => mockNotifications.show(any(), any(), any(), any()));
    });

    test('handleIncomingSms caches fingerprint and enqueues payload with walletId = null on first occurrence', () async {
      final nowMs = DateTime(2026, 8, 23, 6, 30).millisecondsSinceEpoch;
      final message = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': nowMs.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      final expectedFingerprint = 'VF-Cash_تم استلام مبلغ 500 جنيه من رقم 01012345678_${nowMs ~/ 60000}';

      when(() => mockStorage.isSmsProcessed(expectedFingerprint)).thenAnswer((_) async => false);
      when(() => mockStorage.cacheSmsFingerprint(expectedFingerprint)).thenAnswer((_) async {});

      await handleIncomingSms(message, mockStorage);

      verify(() => mockStorage.isSmsProcessed(expectedFingerprint)).called(1);
      verify(() => mockStorage.cacheSmsFingerprint(expectedFingerprint)).called(1);

      // Verify SIM-free payload with walletId: null
      final captured = verify(() => mockStorage.enqueueOverlayData(captureAny())).captured;
      expect(captured.length, 1);
      final payload = captured.first as Map<String, dynamic>;
      expect(payload['amount'], 500.0);
      expect(payload['walletId'], isNull, reason: 'SIM-based routing removed; walletId must be null');
      expect(payload['sender'], '01012345678');
      expect(payload['type'], 'credit');
      expect(payload['provider'], 'Vodafone Cash');
    });

    test('handleIncomingSms generates distinct fingerprints for different timestamp minutes', () async {
      final minute1Ms = DateTime(2026, 8, 23, 6, 30).millisecondsSinceEpoch;
      final minute2Ms = DateTime(2026, 8, 23, 6, 31).millisecondsSinceEpoch;

      final message1 = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': minute1Ms.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      final message2 = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': minute2Ms.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      final fp1 = 'VF-Cash_تم استلام مبلغ 500 جنيه من رقم 01012345678_${minute1Ms ~/ 60000}';
      final fp2 = 'VF-Cash_تم استلام مبلغ 500 جنيه من رقم 01012345678_${minute2Ms ~/ 60000}';

      expect(fp1, isNot(equals(fp2)));

      when(() => mockStorage.isSmsProcessed(fp1)).thenAnswer((_) async => false);
      when(() => mockStorage.cacheSmsFingerprint(fp1)).thenAnswer((_) async {});
      when(() => mockStorage.isSmsProcessed(fp2)).thenAnswer((_) async => false);
      when(() => mockStorage.cacheSmsFingerprint(fp2)).thenAnswer((_) async {});

      await handleIncomingSms(message1, mockStorage);
      await handleIncomingSms(message2, mockStorage);

      verify(() => mockStorage.cacheSmsFingerprint(fp1)).called(1);
      verify(() => mockStorage.cacheSmsFingerprint(fp2)).called(1);
      verify(() => mockStorage.enqueueOverlayData(any())).called(2);
    });
  });
}
