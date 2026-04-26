import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/domain/usecases/transaction_fee_calculator.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';

void main() {
  late TransactionFeeCalculator calculator;

  setUp(() {
    calculator = TransactionFeeCalculator();
  });

  group('TransactionFeeCalculator (Phase 3)', () {
    test('should return willExceedLimits: true when wallet is null', () {
      final result = calculator.calculate(
        wallet: null,
        transactionType: TransactionType.debit,
        amount: 100.0,
        commission: 5.0,
        receiverPhone: '01234567890',
      );

      expect(result.willExceedLimits, isTrue);
    });
  });
}
