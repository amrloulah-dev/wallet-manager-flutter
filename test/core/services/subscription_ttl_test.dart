import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:another_telephony/telephony.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:walletmanager/core/services/sms_processing_pipeline.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

class FakeInitializationSettings extends Fake implements InitializationSettings {}
class FakeNotificationDetails extends Fake implements NotificationDetails {}

void main() {
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
    
    when(() => mockNotifications.initialize(any())).thenAnswer((_) async => true);
    when(() => mockNotifications.show(any(), any(), any(), any())).thenAnswer((_) async {});
  });

  group('Subscription TTL Validation', () {
    test('handleIncomingSms should block processing and notify if sync is stale', () async {
      // Setup: Subscription sync is NOT fresh (>24h)
      when(() => mockStorage.isSubscriptionSyncFresh).thenReturn(false);

      final message = SmsMessage.fromMap({}, []); // Dummy message

      await handleIncomingSms(message, mockStorage);

      // Verify: showStaleSyncNotification was called (ID 8888)
      verify(() => mockNotifications.show(
        8888,
        '⚠️ تنبيه مزامنة',
        'انتهت صلاحية مزامنة الاشتراك. يرجى فتح التطبيق لتحديث بياناتك.',
        any(),
      )).called(1);

      // Verify: No further processing (e.g. parser not called)
      // Since handleIncomingSms is a black box, we check that wake up notification wasn't called
      verifyNever(() => mockNotifications.show(
        any(that: isNot(8888)),
        any(),
        any(),
        any(),
      ));
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
}
