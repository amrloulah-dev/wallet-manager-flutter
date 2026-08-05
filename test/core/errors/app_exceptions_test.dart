import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';

void main() {
  group('InstaPayLimitWarningException Tests', () {
    test('should extend AppException and have instapay_limit_warning message',
        () {
      final exception = InstaPayLimitWarningException();

      expect(exception, isA<AppException>());
      expect(exception.message, equals('instapay_limit_warning'));
    });

    test('should be catchable distinctly from ValidationException', () {
      bool caughtWarning = false;
      bool caughtValidation = false;

      try {
        throw InstaPayLimitWarningException();
      } on InstaPayLimitWarningException {
        caughtWarning = true;
      } on ValidationException {
        caughtValidation = true;
      }

      expect(caughtWarning, isTrue);
      expect(caughtValidation, isFalse);
    });
  });
}
