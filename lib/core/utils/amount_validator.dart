import 'package:walletmanager/core/errors/app_exceptions.dart';

class AmountValidator {
  /// Throws [DomainException] if the [value] is less than or equal to zero.
  static void ensurePositive(double value) {
    if (value <= 0) {
      throw DomainException('يجب أن يكون المبلغ أكبر من صفر');
    }
  }
}
