import 'package:walletmanager/core/errors/app_exceptions.dart';

class AmountValidator {
  /// Throws [DomainException] if the [value] is less than or equal to zero,
  /// or if it is not a finite number (NaN/Infinity).
  static void ensurePositive(double value) {
    if (!value.isFinite) {
      throw DomainException('قيمة غير صالحة');
    }
    if (value <= 0) {
      throw DomainException('يجب أن يكون المبلغ أكبر من صفر');
    }
  }

  /// Throws [DomainException] if the [value] is less than zero,
  /// or if it is not a finite number (NaN/Infinity).
  static void ensurePositiveOrZero(double value) {
    if (!value.isFinite) {
      throw DomainException('قيمة غير صالحة');
    }
    if (value < 0) {
      throw DomainException('يجب أن لا يكون المبلغ سالباً');
    }
  }
}
