import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';

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
    required String? transactionType,
    required double amount,
    required double commission,
    required String receiverPhone,
  }) {
    double fee = 0.0;
    if (wallet != null && transactionType == 'send') {
      fee = FeeCalculator.calculateTransactionFee(
        amount: amount,
        sourceWalletType: wallet.walletType,
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

    if (wallet != null && transactionType != null) {
      final isSend = transactionType == 'send';
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
