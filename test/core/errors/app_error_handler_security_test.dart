import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:walletmanager/core/services/analytics_service.dart';

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  group('AppErrorHandler Security Sanitization (Phase 11)', () {
    late MockFirebaseCrashlytics mockCrashlytics;

    setUp(() {
      mockCrashlytics = MockFirebaseCrashlytics();
      // We can't easily mock FirebaseCrashlytics.instance because it's a static getter.
      // But we can use the plugin's internal mechanism if it allows it.
      // Alternatively, we test the logDiagnostic output or the message passed to logError.

      AppErrorHandler.isTestMode = false; // We want to test the 'handle' logic
      AnalyticsService.isTestMode = true;
    });

    test('sanitizeMessage should strip phone numbers', () {
      const msg = 'User with phone 01012345678 failed to sync';
      final sanitized = AppErrorHandler.sanitizeMessage(msg);

      expect(sanitized, isNot(contains('01012345678')));
      expect(sanitized, contains('[PHONE]'));
    });

    test('sanitizeMessage should strip sensitive financial terms', () {
      const msg1 = 'Error: balance: 123.45 is too low';
      const msg2 = 'Transaction amount: 1000 failed';

      expect(AppErrorHandler.sanitizeMessage(msg1),
          contains('balance: [SENSITIVE]'));
      expect(AppErrorHandler.sanitizeMessage(msg2),
          contains('amount: [SENSITIVE]'));
    });

    test('sanitizeMessage should be case-insensitive for keywords', () {
      const msg = 'BALANCE: 500';
      expect(AppErrorHandler.sanitizeMessage(msg),
          contains('BALANCE: [SENSITIVE]'));
    });
  });
}
