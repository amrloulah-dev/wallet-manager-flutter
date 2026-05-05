import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/error_severity.dart';
import 'package:walletmanager/core/services/analytics_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> printLogs;
  late void Function(String?, {int? wrapWidth}) originalDebugPrint;

  setUp(() {
    AnalyticsService.isTestMode = true;
    printLogs = [];
    originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) printLogs.add(message);
    };
  });

  tearDown(() {
    debugPrint = originalDebugPrint; // restore default
  });

  test('AppErrorHandler.logSilentError triggers debugPrint/log in debug mode', () {
    // This should fail to compile or throw if logSilentError is not implemented
    AppErrorHandler.logSilentError('test error', 'test reason');
    
    // In test environment, kDebugMode is usually true
    // We expect some diagnostic output
    expect(printLogs.any((log) => log.contains('SILENT ERROR')), isTrue);
    expect(printLogs.any((log) => log.contains('test error')), isTrue);
    expect(printLogs.any((log) => log.contains('test reason')), isTrue);
  });

  test('AppErrorHandler low severity triggers debugPrint', () async {
    try {
      AppErrorHandler.handle(
        Exception('test error'),
        severity: ErrorSeverity.low,
        operation: 'test_low',
      );
    } catch (_) {}
    
    expect(printLogs.isNotEmpty, isTrue);
    expect(printLogs.first, contains('[ERROR] [low] [test_low] Exception: test error'));
  });

  test('AppErrorHandler medium severity triggers debugPrint', () async {
    try {
      AppErrorHandler.handle(
        Exception('test error'),
        severity: ErrorSeverity.medium,
        operation: 'test_medium',
      );
    } catch (_) {}

    expect(printLogs.isNotEmpty, isTrue);
    expect(printLogs.first, contains('[ERROR] [medium] [test_medium] Exception: test error'));
  });

  test('AppErrorHandler critical severity triggers debugPrint', () async {
    try {
      AppErrorHandler.handle(
        Exception('test critical error'),
        severity: ErrorSeverity.critical,
        operation: 'test_critical',
      );
    } catch (_) {}

    expect(printLogs.isNotEmpty, isTrue);
    expect(printLogs.first, contains('[ERROR] [critical] [test_critical] Exception: test critical error'));
  });
}
