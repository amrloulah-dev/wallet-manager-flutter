import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

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

  group('SmsProcessingPipeline Single-Item Pipeline Tests', () {
    late MockLocalStorageService mockStorage;
    late MockFlutterLocalNotificationsPlugin mockNotifications;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockStorage = MockLocalStorageService();
      mockNotifications = MockFlutterLocalNotificationsPlugin();

      setNotificationsPlugin(mockNotifications);
      clockNow = () => DateTime(2026, 8, 23, 7, 0);

      when(() => mockStorage.isSmsAutomationEnabled).thenReturn(true);
      when(() => mockStorage.subIsSuspended).thenReturn(false);
      when(() => mockStorage.subSmsEnabled).thenReturn(true);
      when(() => mockStorage.isSubLifetime).thenReturn(true);
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(true);
      when(() => mockStorage.saveCurrentActiveSms(any())).thenAnswer((_) async {});
      when(() => mockStorage.logRejectedSms(
            sender: any(named: 'sender'),
            rawBody: any(named: 'rawBody'),
            reason: any(named: 'reason'),
            failureStep: any(named: 'failureStep'),
          )).thenAnswer((_) async {});
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

    tearDown(() {
      clockNow = DateTime.now;
    });

    test('handleIncomingSms saves single-item payload with walletId = null via saveCurrentActiveSms', () async {
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

      await handleIncomingSms(message, mockStorage);

      // Verify saveCurrentActiveSms was called with SIM-free payload
      final captured = verify(() => mockStorage.saveCurrentActiveSms(captureAny())).captured;
      expect(captured.length, 1);
      final payload = captured.first as Map<String, dynamic>;
      expect(payload['amount'], 500.0);
      expect(payload['walletId'], isNull, reason: 'SIM-based routing removed; walletId must be null');
      expect(payload['sender'], '01012345678');
      expect(payload['type'], 'credit');
      expect(payload['provider'], 'Vodafone Cash');
    });

    test('handleIncomingSms does not block duplicate SMS (No Gate 0 fingerprint filter)', () async {
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

      // Process same message twice
      await handleIncomingSms(message, mockStorage);
      await handleIncomingSms(message, mockStorage);

      // Both invocations should reach saveCurrentActiveSms (single-item overwrite)
      verify(() => mockStorage.saveCurrentActiveSms(any())).called(2);
    });

    test('handleIncomingSms overwrites active SMS with newest incoming data', () async {
      final message1 = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 100 جنيه من رقم 01012345678',
        'date': DateTime(2026, 8, 23, 6, 30).millisecondsSinceEpoch.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      final message2 = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 200 جنيه من رقم 01098765432',
        'date': DateTime(2026, 8, 23, 6, 31).millisecondsSinceEpoch.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      await handleIncomingSms(message1, mockStorage);
      await handleIncomingSms(message2, mockStorage);

      final captured = verify(() => mockStorage.saveCurrentActiveSms(captureAny())).captured;
      expect(captured.length, 2);
      expect((captured[0] as Map)['amount'], 100.0);
      expect((captured[1] as Map)['amount'], 200.0);
    });

    test('handleIncomingSms fires wake-up notification with fullScreenIntent and max priority', () async {
      final message = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': DateTime.now().millisecondsSinceEpoch.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      await handleIncomingSms(message, mockStorage);

      final captured = verify(() => mockNotifications.show(
            any(),
            any(),
            any(),
            captureAny(),
          )).captured;

      expect(captured, isNotEmpty);
      final details = captured.first as NotificationDetails;
      final androidDetails = details.android;
      expect(androidDetails, isNotNull);
      expect(androidDetails!.fullScreenIntent, isTrue,
          reason: 'Notification must have fullScreenIntent: true to wake screen from sleep');
      expect(androidDetails.priority, Priority.max,
          reason: 'Notification priority must be Priority.max');
    });

    test('handleIncomingSms logs STALE_SMS when message is older than 24 hours [TEMP DIAGNOSTIC]', () async {
      final oldDateMs = DateTime(2026, 8, 20, 6, 0).millisecondsSinceEpoch;
      final message = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': oldDateMs.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      await handleIncomingSms(message, mockStorage);

      verify(() => mockStorage.logRejectedSms(
            sender: 'VF-Cash',
            rawBody: any(named: 'rawBody'),
            reason: 'STALE_SMS',
            failureStep: 'MESSAGE_OLDER_THAN_24H',
          )).called(1);
      verifyNever(() => mockStorage.saveCurrentActiveSms(any()));
    });

    test('handleIncomingSms logs SUBSCRIPTION_INACTIVE when SMS automation disabled [TEMP DIAGNOSTIC]', () async {
      when(() => mockStorage.isSmsAutomationEnabled).thenReturn(false);

      final message = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'تم استلام مبلغ 500 جنيه من رقم 01012345678',
        'date': DateTime(2026, 8, 23, 6, 30).millisecondsSinceEpoch.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      await handleIncomingSms(message, mockStorage);

      verify(() => mockStorage.logRejectedSms(
            sender: 'VF-Cash',
            rawBody: any(named: 'rawBody'),
            reason: 'SUBSCRIPTION_INACTIVE',
            failureStep: 'FEATURE_DISABLED',
          )).called(1);
      verifyNever(() => mockStorage.saveCurrentActiveSms(any()));
    });

    test('handleIncomingSms logs parser rejection when SMS cannot be parsed [TEMP DIAGNOSTIC]', () async {
      final message = SmsMessage.fromMap({
        'address': 'VF-Cash',
        'body': 'رسالة بدون مبلغ مالي',
        'date': DateTime(2026, 8, 23, 6, 30).millisecondsSinceEpoch.toString(),
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ]);

      await handleIncomingSms(message, mockStorage);

      verify(() => mockStorage.logRejectedSms(
            sender: 'VF-Cash',
            rawBody: any(named: 'rawBody'),
            reason: 'AMOUNT_NOT_FOUND',
            failureStep: any(named: 'failureStep'),
          )).called(1);
      verifyNever(() => mockStorage.saveCurrentActiveSms(any()));
    });
  });
}
