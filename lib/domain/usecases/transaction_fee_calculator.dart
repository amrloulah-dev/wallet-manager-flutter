import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/utils/amount_validator.dart';
import '../../core/errors/app_exceptions.dart';

class TransactionCalculationResult {
  final double serviceFee;
  final double totalAmount;
  final bool willExceedLimits;
  final double newDailyUsed;
  final double newMonthlyUsed;
  final double dailyLimit;
  final double monthlyLimit;
  final bool dailyExceeded;
  final bool monthlyExceeded;

  TransactionCalculationResult({
    required this.serviceFee,
    required this.totalAmount,
    required this.willExceedLimits,
    required this.newDailyUsed,
    required this.newMonthlyUsed,
    required this.dailyLimit,
    required this.monthlyLimit,
    required this.dailyExceeded,
    required this.monthlyExceeded,
  });
}

class TransactionFeeCalculator {
  TransactionCalculationResult calculate({
    required WalletModel? wallet,
    required TransactionType? transactionType,
    required double amount,
    required double commission,
    required String receiverPhone,
  }) {
    if (wallet == null) {
      throw NotFoundException('Wallet not found for fee calculation');
    }

    if (transactionType == null) {
      throw DomainException('Transaction type is required for fee calculation');
    }

    // Step 1.1: Ensure positive amount at entry
    AmountValidator.ensurePositive(amount);
    // Step 1.2: Ensure commission is non-negative (zero is valid for no-commission txns)
    AmountValidator.ensurePositiveOrZero(commission);

    double fee = 0.0;
    if (transactionType == TransactionType.debit) {
      fee = FeeCalculator.calculateTransactionFee(
        amount: amount,
        sourceWalletType: wallet.walletType.dbValue,
        receiverPhone: receiverPhone,
      );
    }

    // Step 1.1: Total amount must include service fee
    final totalAmount = amount + commission + fee;

    bool willExceed = false;
    double newDailyUsed = 0.0;
    double newMonthlyUsed = 0.0;
    double dailyLimit = 0.0;
    double monthlyLimit = 0.0;
    bool dailyExceeded = false;
    bool monthlyExceeded = false;

    final isSend = transactionType == TransactionType.debit;
    final limits = isSend ? wallet.getLimits() : wallet.getReceiveLimits();
    newDailyUsed = limits.dailyUsed + amount;
    newMonthlyUsed = limits.monthlyUsed + amount;
    dailyLimit = limits.dailyLimit;
    monthlyLimit = limits.monthlyLimit;

    dailyExceeded = newDailyUsed > dailyLimit;
    monthlyExceeded = newMonthlyUsed > monthlyLimit;
    willExceed = dailyExceeded || monthlyExceeded;

    return TransactionCalculationResult(
      serviceFee: fee,
      totalAmount: totalAmount,
      willExceedLimits: willExceed,
      newDailyUsed: newDailyUsed,
      newMonthlyUsed: newMonthlyUsed,
      dailyLimit: dailyLimit,
      monthlyLimit: monthlyLimit,
      dailyExceeded: dailyExceeded,
      monthlyExceeded: monthlyExceeded,
    );
  }
}
