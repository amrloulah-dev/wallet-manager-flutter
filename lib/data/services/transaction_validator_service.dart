import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_helper.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class TransactionValidatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> validateAndSave(TransactionModel transaction) async {
    // Positive Amount Check
    if (transaction.amount <= 0) {
      throw ValidationException('Amount must be positive.');
    }

    final balanceChange = transaction.isSend
        ? -(transaction.amount + transaction.serviceFee)
        : transaction.amount;

    // Wrap the successful validation states inside FirebaseFirestore.instance.runTransaction()
    await _firestore.runTransaction((tx) async {
      final walletRef = _firestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(transaction.walletId);
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) throw NotFoundException('Wallet');

      if (transaction.isDeposit) {
        tx.update(
            walletRef, {'balance': FieldValue.increment(transaction.amount)});
        return;
      }

      var wallet = WalletModel.fromFirestore(walletSnap);
      final now = Timestamp.now();

      var validationWallet = wallet;
      if (validationWallet.needsDailyReset) {
        validationWallet = validationWallet.copyWith(
            sendLimits: validationWallet.sendLimits.copyWith(dailyUsed: 0),
            receiveLimits:
                validationWallet.receiveLimits.copyWith(dailyUsed: 0));
      }
      if (validationWallet.needsMonthlyReset) {
        validationWallet = validationWallet.copyWith(
            sendLimits: validationWallet.sendLimits.copyWith(monthlyUsed: 0),
            receiveLimits:
                validationWallet.receiveLimits.copyWith(monthlyUsed: 0));
      }

      // Explicit capacity and network checks (InstaPay/Telecom)
      final isInstaPay = wallet.walletType == 'instapay';
      final isTelecom = [
        'vodafone_cash',
        'orange_cash',
        'etisalat_cash',
        'we_pay'
      ].contains(wallet.walletType);

      if (isInstaPay && transaction.amount > 70000) {
        throw ValidationException(
            'Maximum single transaction for InstaPay is 70,000 EGP.');
      }
      if (isTelecom && transaction.amount > 60000) {
        throw ValidationException(
            'Maximum single transaction for Telecom wallets is 60,000 EGP.');
      }

      if (transaction.isSend) {
        // Balance Sufficiency Check
        if (validationWallet.balance < transaction.amount) {
          throw ValidationException(
              'المبلغ المراد إرساله أكبر من الرصيد المتاح.');
        }

        if (transaction.amount > validationWallet.getLimits().dailyLimit) {
          throw ValidationException(
              'المبلغ يتجاوز الحد الأقصى للمعاملة الواحدة.');
        }
        if (validationWallet.getLimits().monthlyUsed + transaction.amount >
            validationWallet.getLimits().monthlyLimit) {
          throw ValidationException('تم تجاوز الحد الشهري لهذه المحفظة.');
        }
      } else if (transaction.isReceive) {
        if (transaction.amount >
            validationWallet.getReceiveLimits().dailyLimit) {
          throw ValidationException(
              'المبلغ يتجاوز الحد الأقصى للمعاملة الواحدة.');
        }
        if (validationWallet.getReceiveLimits().monthlyUsed +
                transaction.amount >
            validationWallet.getReceiveLimits().monthlyLimit) {
          throw ValidationException('تم تجاوز الحد الشهري لهذه المحفظة.');
        }
      }

      final txRef = _firestore
          .collection(FirebaseConstants.transactions)
          .doc(transaction.transactionId);
      tx.set(txRef, transaction.toFirestore());

      final Map<String, dynamic> walletUpdateData = {};

      walletUpdateData['balance'] = FieldValue.increment(balanceChange);
      walletUpdateData[
              '${FirebaseConstants.stats}.${FirebaseConstants.totalTransactions}'] =
          FieldValue.increment(1);
      walletUpdateData[
              '${FirebaseConstants.stats}.${FirebaseConstants.lastTransactionDate}'] =
          now;

      final bool needsDailyReset = wallet.needsDailyReset;
      final bool needsMonthlyReset = wallet.needsMonthlyReset;

      if (needsDailyReset) {
        walletUpdateData['lastDailyReset'] = now;
      }
      if (needsMonthlyReset) {
        walletUpdateData['lastMonthlyReset'] = now;
      }

      if (transaction.isSend) {
        walletUpdateData['sendLimits.dailyUsed'] = needsDailyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        walletUpdateData['sendLimits.monthlyUsed'] = needsMonthlyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        if (needsDailyReset) {
          walletUpdateData['receiveLimits.dailyUsed'] = 0.0;
        }
        if (needsMonthlyReset) {
          walletUpdateData['receiveLimits.monthlyUsed'] = 0.0;
        }
      } else if (transaction.isReceive) {
        walletUpdateData['receiveLimits.dailyUsed'] = needsDailyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        walletUpdateData['receiveLimits.monthlyUsed'] = needsMonthlyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        if (needsDailyReset) walletUpdateData['sendLimits.dailyUsed'] = 0.0;
        if (needsMonthlyReset) {
          walletUpdateData['sendLimits.monthlyUsed'] = 0.0;
        }
      }

      if (transaction.isSend || transaction.isReceive) {
        walletUpdateData[
                '${FirebaseConstants.stats}.${transaction.isSend ? FirebaseConstants.totalSentAmount : FirebaseConstants.totalReceivedAmount}'] =
            FieldValue.increment(transaction.amount);
        walletUpdateData[
                '${FirebaseConstants.stats}.${FirebaseConstants.totalCommission}'] =
            FieldValue.increment(transaction.commission);
      }

      tx.update(walletRef, walletUpdateData);

      // Update Daily Stats
      final dailyStatsRef = _firestore
          .collection('stores')
          .doc(transaction.storeId)
          .collection('daily_stats')
          .doc(DateHelper.getCurrentDateString());

      tx.set(
        dailyStatsRef,
        {
          'transactionCount': FieldValue.increment(1),
          'totalCommission': FieldValue.increment(transaction.commission),
          'totalAmount': FieldValue.increment(transaction.amount),
        },
        SetOptions(merge: true),
      );
    });
  }
}
