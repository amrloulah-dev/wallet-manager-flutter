import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  late MockLocalStorageService mockStorage;
  late MockFlutterLocalNotificationsPlugin mockNotifications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockStorage = MockLocalStorageService();
    mockNotifications = MockFlutterLocalNotificationsPlugin();

    // Set mock notifications plugin
    setNotificationsPlugin(mockNotifications);

    // Default mock behaviors
    when(() => mockStorage.isSmsAutomationEnabled).thenReturn(true);
    when(() => mockStorage.subIsSuspended).thenReturn(false);
    when(() => mockStorage.subSmsEnabled).thenReturn(true);
    when(() => mockStorage.isSubLifetime).thenReturn(true);
    when(() => mockStorage.saveToVault(any())).thenAnswer((_) async {});
    when(() => mockStorage.reloadDisk()).thenAnswer((_) async {});
    when(() => mockStorage.clearVault()).thenAnswer((_) async {});
    when(() => mockStorage.cacheWalletLiteList(any())).thenAnswer((_) async {});

    when(() => mockNotifications.initialize(any()))
        .thenAnswer((_) async => true);
    when(() => mockNotifications.show(any(), any(), any(), any()))
        .thenAnswer((_) async {});
  });

  group('Subscription TTL Validation', () {
    test(
        'handleIncomingSms should block processing and notify if sync is stale with exact text and unique ID',
        () async {
      // Setup: Subscription sync is NOT fresh (>24h)
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(false);

      final message = SmsMessage.fromMap({}, []); // Dummy message

      await handleIncomingSms(message, mockStorage);

      // Verify: showStaleSyncNotification was called
      // We expect a unique ID (not hardcoded 8888) and exact text
      verify(() => mockNotifications.show(
            any(that: isNot(8888)), // Should be unique now
            any(),
            '⚠️ انتهت صلاحية مزامنة الاشتراك. يرجى فتح التطبيق لتحديث بياناتك.',
            any(),
          )).called(1);

      // Verify: No further processing
      verifyNever(() => mockNotifications.show(
            any(),
            'معاملة جديدة',
            any(),
            any(),
          ));
    });

    test(
        'handleIncomingSms should use unique notification IDs for multiple stale sync messages',
        () async {
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(false);

      final message1 = SmsMessage.fromMap({}, []);
      final message2 = SmsMessage.fromMap({}, []);

      await handleIncomingSms(message1, mockStorage);
      await Future.delayed(const Duration(milliseconds: 1)); // Ensure unique ID
      await handleIncomingSms(message2, mockStorage);

      final captured = verify(() => mockNotifications.show(
            captureAny(),
            any(),
            any(),
            any(),
          )).captured;

      expect(captured.length, greaterThanOrEqualTo(2));
      expect(captured[0], isNot(equals(captured[1])));
    });

    test('handleIncomingSms should proceed if sync is fresh', () async {
      // Setup: Subscription sync IS fresh
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(true);

      final message = SmsMessage.fromMap({}, []);

      await handleIncomingSms(message, mockStorage);

      verifyNever(() => mockNotifications.show(
            8888,
            any(),
            any(),
            any(),
          ));
    });
  });

  group('Unique Notification IDs', () {
    test(
        'handleIncomingSms should use unique notification IDs for multiple messages',
        () async {
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(true);
      when(() => mockStorage.getSimMappings()).thenReturn([]);

      // Need valid parseable SMS to reach _showWakeUpNotification
      // Mocking the parser engine is not easily possible as it's instantiated inside handleIncomingSms.
      // But we can simulate multiple calls and check collected IDs.

      // Since _showWakeUpNotification is private, we verify via mockNotifications.show
      // We'll use a valid Vodafone SMS for the parser to succeed
      final message1 = SmsMessage.fromMap({
        'address': 'Vodafone',
        'body': 'تم تحويل 100 جنيه لرقم 01012345678',
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY
      ]);

      final message2 = SmsMessage.fromMap({
        'address': 'Vodafone',
        'body': 'تم تحويل 200 جنيه لرقم 01012345678',
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY
      ]);

      // Mock Overlay permissions
      const channel = MethodChannel('x-slayer/flutter_overlay_window');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'isPermissionGranted') return true;
        if (methodCall.method == 'isActive') return false;
        if (methodCall.method == 'showOverlay') return true;
        if (methodCall.method == 'shareData') return true;
        return null;
      });

      await handleIncomingSms(message1, mockStorage);
      await Future.delayed(const Duration(milliseconds: 1)); // Ensure unique ID
      await handleIncomingSms(message2, mockStorage);

      final captured = verify(() => mockNotifications.show(
            captureAny(),
            any(),
            any(),
            any(),
          )).captured;

      expect(captured.length, greaterThanOrEqualTo(2));
      expect(captured[0], isNot(equals(captured[1])));
    });
  });
}
