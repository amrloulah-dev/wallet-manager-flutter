import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/utils/amount_validator.dart';

void main() {
  group('AmountValidator.ensurePositive', () {
    test('should throw DomainException if value is negative', () {
      expect(() => AmountValidator.ensurePositive(-1.0),
          throwsA(isA<DomainException>()));
    });

    test('should throw DomainException if value is zero', () {
      expect(() => AmountValidator.ensurePositive(0.0),
          throwsA(isA<DomainException>()));
    });

    test('should NOT throw if value is positive', () {
      expect(() => AmountValidator.ensurePositive(10.5), returnsNormally);
    });
  });
}
