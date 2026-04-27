import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';

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
    required TransactionType? transactionType, // ENUM refactor
    required double amount,
    required double commission,
    required String receiverPhone,
  }) {
    if (wallet == null) {
      return TransactionCalculationResult(
        serviceFee: 0.0,
        totalAmount: amount + commission,
        willExceedLimits: true,
        newDailyUsed: 0.0,
        newMonthlyUsed: 0.0,
        dailyLimit: 0.0,
        monthlyLimit: 0.0,
        dailyExceeded: false,
        monthlyExceeded: false,
      );
    }

    double fee = 0.0;
    if (transactionType == TransactionType.debit) {
      fee = FeeCalculator.calculateTransactionFee(
        amount: amount,
        sourceWalletType: wallet.walletType.name, // ENUM refactor
        receiverPhone: receiverPhone,
      );
    }

    final totalAmount = amount + commission;

    bool willExceed = false;
    double newDailyUsed = 0.0;
    double newMonthlyUsed = 0.0;
    double dailyLimit = 0.0;
    double monthlyLimit = 0.0;
    bool dailyExceeded = false;
    bool monthlyExceeded = false;

    if (transactionType != null) {
      final isSend = transactionType == TransactionType.debit;
      final limits = isSend ? wallet.getLimits() : wallet.getReceiveLimits();
      newDailyUsed = limits.dailyUsed + amount;
      newMonthlyUsed = limits.monthlyUsed + amount;
      dailyLimit = limits.dailyLimit;
      monthlyLimit = limits.monthlyLimit;

      dailyExceeded = newDailyUsed > dailyLimit;
      monthlyExceeded = newMonthlyUsed > monthlyLimit;
      willExceed = dailyExceeded || monthlyExceeded;
    }

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
