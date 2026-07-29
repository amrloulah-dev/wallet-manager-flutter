import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/validators.dart';

void main() {
  group('Validators.validatePin', () {
    test('returns error when pin is null or empty', () {
      expect(Validators.validatePin(null), 'يرجى إدخال الرقم السري');
      expect(Validators.validatePin(''), 'يرجى إدخال الرقم السري');
    });

    test('returns error when pin is not exactly 6 digits', () {
      expect(Validators.validatePin('1234'), 'الرقم السري يجب أن يكون 6 أرقام');
      expect(Validators.validatePin('12345'), 'الرقم السري يجب أن يكون 6 أرقام');
      expect(Validators.validatePin('1234567'), 'الرقم السري يجب أن يكون 6 أرقام');
    });

    test('returns error when pin contains non-digit characters', () {
      expect(Validators.validatePin('12345a'), 'الرقم السري يجب أن يكون 6 أرقام');
      expect(Validators.validatePin('abcdef'), 'الرقم السري يجب أن يكون 6 أرقام');
    });

    test('returns null for valid 6-digit pin', () {
      expect(Validators.validatePin('123456'), isNull);
      expect(Validators.validatePin('000000'), isNull);
      expect(Validators.validatePin('987654'), isNull);
    });
  });
}
