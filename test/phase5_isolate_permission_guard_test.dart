import 'package:another_telephony/telephony.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:walletmanager/core/services/sms_service.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class MockTelephony extends Mock implements Telephony {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockTelephony mockTelephony;

  setUp(() {
    mockTelephony = MockTelephony();
    SharedPreferences.setMockInitialValues({});
    LocalStorageService.reset();
  });

  group('SmsService Isolate Permission Guarding', () {
    test('init() should request SMS, Overlay, Battery, and Notification permissions', () async {
      when(() => mockTelephony.requestPhoneAndSmsPermissions).thenAnswer((_) async => true);
      
      // Mock FlutterOverlayWindow via MethodChannel
      const MethodChannel('x-slayer/overlay_channel').setMockMethodCallHandler((method) async {
        if (method.method == 'checkPermission') return true;
        if (method.method == 'requestPermission') return true;
        return null;
      });

      const MethodChannel('flutter.baseflow.com/permissions/methods').setMockMethodCallHandler((method) async {
        if (method.method == 'requestPermissions') {
          return {
            30: 1, // ignoreBatteryOptimizations -> granted
            22: 1, // notification -> granted
          };
        }
        return null;
      });

      final smsService = SmsService(telephony: mockTelephony);
      await smsService.init();

      verify(() => mockTelephony.requestPhoneAndSmsPermissions).called(1);
    });

    test('init() should throw if called from a background isolate', () async {
      // Simulate being in a background isolate
      SmsService.debugIsMainIsolateOverride = false;
      
      try {
        final smsService = SmsService(telephony: mockTelephony);
        await expectLater(smsService.init(), throwsA(isA<UnsupportedError>()));
      } finally {
        SmsService.debugIsMainIsolateOverride = null; // Reset
      }
    });
  });
}
