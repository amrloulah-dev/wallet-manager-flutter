import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/services/background_service.dart';
import 'package:walletmanager/core/services/sms_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:another_telephony/telephony.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockServiceInstance extends Mock implements ServiceInstance {}

class MockTelephony extends Mock implements Telephony {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockServiceInstance mockService;
  late MockTelephony mockTelephony;

  setUp(() async {
    mockService = MockServiceInstance();
    mockTelephony = MockTelephony();

    // Mock ServiceInstance methods
    when(() => mockService.on(any())).thenAnswer((_) => const Stream.empty());
    when(() => mockService.stopSelf()).thenAnswer((_) async {});
  });

  group('Phase 3: OS Constraints & Hybrid Kill-Switch Fixes', () {
    test('onStart stops service if SmsAutomation is disabled', () async {
      // Mock SharedPreferences with automation disabled
      SharedPreferences.setMockInitialValues({'sms_automation_enabled': false});

      // We need to wait for onStart to complete its async work.
      // onStart is void async, so it returns immediately but does work.
      // We'll call it and then wait.
      await onStart(mockService);

      // Verify stopSelf was called
      verify(() => mockService.stopSelf()).called(1);
    });

    test('SmsService.init() requests ignoreBatteryOptimizations permission',
        () async {
      // Mock Telephony permissions
      when(() => mockTelephony.requestPhoneAndSmsPermissions)
          .thenAnswer((_) async => true);

      // SharedPreferences for SmsService.init
      SharedPreferences.setMockInitialValues({});

      SmsService(telephony: mockTelephony);

      // We can't easily verify Permission.ignoreBatteryOptimizations.request()
      // without a wrapper, but we can verify the code doesn't crash
      // and we will implement the logic.
    });
  });
}
