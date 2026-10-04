import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_telephony/telephony.dart';

import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/core/services/sms_service.dart';

class MockOverlayUseCase extends Mock implements OverlayUseCase {}

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockTelephony extends Mock implements Telephony {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockOverlayUseCase mockOverlayUseCase;
  late MockLocalStorageService mockLocalStorageService;
  late MockTelephony mockTelephony;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockOverlayUseCase = MockOverlayUseCase();
    mockLocalStorageService = MockLocalStorageService();
    mockTelephony = MockTelephony();

    // Mock the method channel for flutter_overlay_window
    const channel = MethodChannel('x-slayer/overlay_channel');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'closeOverlay') {
        return true;
      }
      return null;
    });

    // Mock telephony permissions
    when(() => mockTelephony.requestPhoneAndSmsPermissions)
        .thenAnswer((_) async => true);

    // Mock secure storage
    const secureStorageChannel =
        MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (methodCall) async {
      return null;
    });

    // Mock permission_handler
    const MethodChannel('flutter.baseflow.com/permissions/methods')
        .setMockMethodCallHandler((methodCall) async {
      if (methodCall.method == 'checkPermissionStatus') {
        return 1; // granted
      }
      if (methodCall.method == 'requestPermissions') {
        return {
          21: 1, // ignoreBatteryOptimizations
          33: 1, // notification
        };
      }
      return null;
    });
  });

  group('Phase 1: Data Duplication & Stale State Fixes', () {
    test('closing overlay clears active SMS cache', () async {
      final provider = OverlayProvider(
        overlayUseCase: mockOverlayUseCase,
        localStorageService: mockLocalStorageService,
      );

      when(() => mockLocalStorageService.clearCurrentActiveSms()).thenAnswer((_) async {});

      await provider.close();

      verify(() => mockLocalStorageService.clearCurrentActiveSms()).called(1);
    });

    test('SmsService.init() does NOT register listener (should fail initially)',
        () async {
      // This test will fail to compile initially because SmsService doesn't support DI.
      // After refactoring, it will fail because SmsService CURRENTLY registers a listener.
      final smsService = SmsService(telephony: mockTelephony);

      await smsService.init();

      // We expect listenIncomingSms NOT to be called
      verifyNever(() => mockTelephony.listenIncomingSms(
            onNewMessage: any(named: 'onNewMessage'),
            onBackgroundMessage: any(named: 'onBackgroundMessage'),
            listenInBackground: any(named: 'listenInBackground'),
          ));
    });
  });
}
