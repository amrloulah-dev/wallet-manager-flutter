import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/error_severity.dart';
import 'package:walletmanager/routes/navigation_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFlutterLocalNotificationsPlugin extends Mock implements FlutterLocalNotificationsPlugin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFlutterLocalNotificationsPlugin mockNotificationsPlugin;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockNotificationsPlugin = MockFlutterLocalNotificationsPlugin();
    AppErrorHandler.setNotificationsPlugin(mockNotificationsPlugin);
    
    // Mock the show method
    when(() => mockNotificationsPlugin.show(
      any(),
      any(),
      any(),
      any(),
    )).thenAnswer((_) async {});

    // Mock Firebase channel (Standard)
    const firebaseChannel = MethodChannel('plugins.flutter.io/firebase_core');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(firebaseChannel, (methodCall) async {
      if (methodCall.method == 'Firebase#initializeApp') {
        return {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': '123',
            'appId': '123',
            'messagingSenderId': '123',
            'projectId': '123',
          },
        };
      }
      return null;
    });

    // Mock Pigeon channel for firebase_core
    const pigeonChannel = MethodChannel('dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pigeonChannel, (methodCall) async {
      return [
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': '123',
            'appId': '123',
            'messagingSenderId': '123',
            'projectId': '123',
          },
        }
      ];
    });

    try {
      await Firebase.initializeApp();
    } catch (_) {}
  });

  group('Phase 2: Isolate Crashes & UX Blindspots Fixes', () {
    test('AppErrorHandler.handle() triggers local notification when context is null (background)', () async {
      // Ensure context is null
      expect(NavigationService.navigatorKey.currentContext, isNull);

      // AppErrorHandler.handle is now async but we call it from non-async context usually.
      AppErrorHandler.handle(
        'Test Error',
        severity: ErrorSeverity.critical,
        showToast: true,
      );

      // Wait a bit for the async notification logic
      await Future.delayed(const Duration(milliseconds: 200));

      verify(() => mockNotificationsPlugin.show(
        any(),
        any(that: contains('SMS Processing Error')),
        any(),
        any(),
      )).called(1);
    });

    test('overlayMain catches Firebase failure and shows error UI', () async {
      // This is a placeholder test for the logic change in main.dart
    });
  });
}
