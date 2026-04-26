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

    test('should throw DomainException if value is NaN', () {
      expect(() => AmountValidator.ensurePositive(double.nan),
          throwsA(isA<DomainException>()));
    });

    test('should throw DomainException if value is infinite', () {
      expect(() => AmountValidator.ensurePositive(double.infinity),
          throwsA(isA<DomainException>()));
      expect(() => AmountValidator.ensurePositive(double.negativeInfinity),
          throwsA(isA<DomainException>()));
    });
  });

  group('AmountValidator.ensurePositiveOrZero', () {
    test('should throw DomainException if value is negative', () {
      expect(() => AmountValidator.ensurePositiveOrZero(-0.1),
          throwsA(isA<DomainException>()));
    });

    test('should NOT throw if value is zero', () {
      expect(() => AmountValidator.ensurePositiveOrZero(0.0), returnsNormally);
    });

    test('should NOT throw if value is positive', () {
      expect(() => AmountValidator.ensurePositiveOrZero(10.5), returnsNormally);
    });

    test('should throw DomainException if value is NaN', () {
      expect(() => AmountValidator.ensurePositiveOrZero(double.nan),
          throwsA(isA<DomainException>()));
    });

    test('should throw DomainException if value is infinite', () {
      expect(() => AmountValidator.ensurePositiveOrZero(double.infinity),
          throwsA(isA<DomainException>()));
    });
  });
}
