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

    setNotificationsPlugin(mockNotifications);

    when(() => mockStorage.isSmsAutomationEnabled).thenReturn(true);
    when(() => mockStorage.subIsSuspended).thenReturn(false);
    when(() => mockStorage.subSmsEnabled).thenReturn(true);
    when(() => mockStorage.isSubLifetime).thenReturn(true);
    when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(true);
    when(() => mockStorage.getSimMappings()).thenReturn([]);
    when(() => mockStorage.saveToVault(any())).thenAnswer((_) async {});
    when(() => mockStorage.enqueueOverlayData(any())).thenAnswer((_) async {});

    when(() => mockNotifications.initialize(any()))
        .thenAnswer((_) async => true);
    when(() => mockNotifications.show(any(), any(), any(), any()))
        .thenAnswer((_) async {});
  });

  group('Dynamic Overlay Update', () {
    test(
        'handleIncomingSms should call shareData and NOT showOverlay if overlay is already active',
        () async {
      final message = SmsMessage.fromMap({
        'address': 'Vodafone',
        'body': 'تم تحويل مبلغ 100 جنيه لرقم 01012345678',
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY
      ]);

      int showOverlayCount = 0;
      int shareDataCount = 0;
      int closeOverlayCount = 0;

      const channel = MethodChannel('x-slayer/overlay_channel');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'checkPermission') return true;
        if (methodCall.method == 'isPermissionGranted') return true;
        if (methodCall.method == 'isActive' ||
            methodCall.method == 'isOverlayActive') {
          return true; // ALREADY ACTIVE
        }
        if (methodCall.method == 'showOverlay') {
          showOverlayCount++;
          return true;
        }
        if (methodCall.method == 'closeOverlay') {
          closeOverlayCount++;
          return true;
        }
        return null;
      });

      const messageChannel =
          BasicMessageChannel('x-slayer/overlay_messenger', JSONMessageCodec());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(messageChannel.name, (message) async {
        shareDataCount++;
        return null;
      });

      await handleIncomingSms(message, mockStorage);

      expect(showOverlayCount, 0,
          reason: 'showOverlay should not be called if overlay is active');
      expect(closeOverlayCount, 0,
          reason: 'closeOverlay should not be called in dynamic update path');
      expect(shareDataCount, 1,
          reason: 'shareData should be called to update active overlay');
    });

    test('handleIncomingSms should call showOverlay if overlay is NOT active',
        () async {
      final message = SmsMessage.fromMap({
        'address': 'Vodafone',
        'body': 'تم تحويل مبلغ 100 جنيه لرقم 01012345678',
      }, [
        SmsColumn.ADDRESS,
        SmsColumn.BODY
      ]);

      int showOverlayCount = 0;
      int shareDataCount = 0;

      const channel = MethodChannel('x-slayer/overlay_channel');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        if (methodCall.method == 'checkPermission') return true;
        if (methodCall.method == 'isPermissionGranted') return true;
        if (methodCall.method == 'isActive' ||
            methodCall.method == 'isOverlayActive') {
          return false; // NOT ACTIVE
        }
        if (methodCall.method == 'showOverlay') {
          showOverlayCount++;
          return true;
        }
        return null;
      });

      const messageChannel =
          BasicMessageChannel('x-slayer/overlay_messenger', JSONMessageCodec());
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(messageChannel.name, (message) async {
        shareDataCount++;
        return null;
      });

      await handleIncomingSms(message, mockStorage);

      expect(showOverlayCount, 1,
          reason: 'showOverlay should be called if overlay is not active');
      expect(shareDataCount, 1,
          reason: 'shareData should be called after showOverlay');
    });
  });
}
