import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_helper.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

class TransactionValidatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> validateAndSave(TransactionModel transaction) async {
    debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> validateAndSave: '
        'ENTRY | txId=${transaction.transactionId}, walletId=${transaction.walletId}, '
        'type=${transaction.transactionType}, amount=${transaction.amount}, '
        'serviceFee=${transaction.serviceFee}, commission=${transaction.commission}, '
        'storeId=${transaction.storeId}');

    // 1. Positive Amount Check
    if (transaction.amount <= 0) {
      throw ValidationException('المبلغ يجب أن يكون أكبر من الصفر.');
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
      if (!walletSnap.exists) throw NotFoundException('المحفظة غير موجودة.');

      // Handle simple deposit immediately
      if (transaction.isDeposit) {
        tx.update(
            walletRef, {'balance': FieldValue.increment(transaction.amount)});
        return;
      }

      var wallet = WalletModel.fromFirestore(walletSnap);
      final now = Timestamp.now();

      debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
          'walletFetched | walletId=${wallet.walletId}, '
          'walletType=${wallet.walletType}, currentBalance=${wallet.balance}, '
          'totalDeduction=${transaction.amount + transaction.serviceFee}, '
          'balanceChange=$balanceChange');

      // Reset limits locally for validation logic if needed
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

      // ------------------------------------------------------------------
      // 2. EXPLICIT NETWORK LIMITS (InstaPay / Telecom) - Single Transaction
      // ------------------------------------------------------------------
      final isInstaPay = wallet.walletType == 'instapay';
      final isTelecom = [
        'vodafone_cash',
        'orange_cash',
        'etisalat_cash',
        'we_pay'
      ].contains(wallet.walletType);

      if (isInstaPay && transaction.amount > 70000) {
        throw ValidationException('الحد الأقصى للمعاملة الواحدة لإنستاباي هو 70,000 جنيه.');
      }
      if (isTelecom && transaction.amount > 60000) {
        throw ValidationException('الحد الأقصى للمعاملة الواحدة للمحافظ الإلكترونية هو 60,000 جنيه.');
      }

      // ------------------------------------------------------------------
      // 3. CORE RULE: Balance Sufficiency Check
      // ------------------------------------------------------------------
      if (transaction.isSend) {
        final totalDeduction = transaction.amount + transaction.serviceFee;
        debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
            'BALANCE CHECK | balance=${validationWallet.balance}, '
            'totalDeduction=$totalDeduction, '
            'sufficient=${validationWallet.balance >= totalDeduction}');
        if (validationWallet.balance < totalDeduction) {
          throw ValidationException('المبلغ المراد إرساله (مع العمولة) أكبر من الرصيد المتاح.');
        }
      }

      // ------------------------------------------------------------------
      // 4. CUMULATIVE LIMITS (InstaPay & General Capacity)
      // ------------------------------------------------------------------
      // InstaPay explicit daily limit check (Applies to both Send and Receive)
      if (isInstaPay) {
        num usedAmount = transaction.isSend
            ? validationWallet.sendLimits.dailyUsed
            : validationWallet.receiveLimits.dailyUsed;
            
        debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
            'INSTAPAY DAILY LIMIT | dailyUsed=$usedAmount, '
            'incoming=${transaction.amount}, total=${usedAmount + transaction.amount}');
        if (usedAmount + transaction.amount > 120000) {
          throw ValidationException('تم تجاوز الحد اليومي لمحفظة InstaPay (120,000 جنيه).');
        }
      }

      // ------------------------------------------------------------------
      // GENERAL WALLET CAPACITY LIMITS
      // ------------------------------------------------------------------
      if (transaction.isSend) {
        debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
            'SEND LIMITS | dailyUsed=${validationWallet.sendLimits.dailyUsed}, '
            'dailyLimit=${validationWallet.getLimits().dailyLimit}, '
            'monthlyUsed=${validationWallet.sendLimits.monthlyUsed}, '
            'monthlyLimit=${validationWallet.getLimits().monthlyLimit}');
        if (validationWallet.sendLimits.dailyUsed + transaction.amount > validationWallet.getLimits().dailyLimit) {
          throw ValidationException('تم تجاوز الحد اليومي للإرسال لهذه المحفظة.');
        }
        if (validationWallet.sendLimits.monthlyUsed + transaction.amount > validationWallet.getLimits().monthlyLimit) {
          throw ValidationException('تم تجاوز الحد الشهري للإرسال لهذه المحفظة.');
        }
      } else if (transaction.isReceive) {
        debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
            'RECEIVE LIMITS | dailyUsed=${validationWallet.receiveLimits.dailyUsed}, '
            'dailyLimit=${validationWallet.getReceiveLimits().dailyLimit}, '
            'monthlyUsed=${validationWallet.receiveLimits.monthlyUsed}, '
            'monthlyLimit=${validationWallet.getReceiveLimits().monthlyLimit}');
        if (validationWallet.receiveLimits.dailyUsed + transaction.amount > validationWallet.getReceiveLimits().dailyLimit) {
          throw ValidationException('تم تجاوز الحد اليومي للاستقبال لهذه المحفظة.');
        }
        if (validationWallet.receiveLimits.monthlyUsed + transaction.amount > validationWallet.getReceiveLimits().monthlyLimit) {
          throw ValidationException('تم تجاوز الحد الشهري للاستقبال لهذه المحفظة.');
        }
      }

      // ------------------------------------------------------------------
      // 5. DATABASE WRITES (Atomic execution)
      // ------------------------------------------------------------------
      
      // Save Transaction Document
      final txRef = _firestore
          .collection(FirebaseConstants.transactions)
          .doc(transaction.transactionId);
      tx.set(txRef, transaction.toFirestore());

      // Prepare Wallet Updates
      final Map<String, dynamic> walletUpdateData = {};

      walletUpdateData['balance'] = FieldValue.increment(balanceChange);
      walletUpdateData['${FirebaseConstants.stats}.${FirebaseConstants.totalTransactions}'] = FieldValue.increment(1);
      walletUpdateData['${FirebaseConstants.stats}.${FirebaseConstants.lastTransactionDate}'] = now;

      final bool needsDailyReset = wallet.needsDailyReset;
      final bool needsMonthlyReset = wallet.needsMonthlyReset;

      if (needsDailyReset) walletUpdateData['lastDailyReset'] = now;
      if (needsMonthlyReset) walletUpdateData['lastMonthlyReset'] = now;

      if (transaction.isSend) {
        walletUpdateData['sendLimits.dailyUsed'] = needsDailyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        walletUpdateData['sendLimits.monthlyUsed'] = needsMonthlyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        if (needsDailyReset) walletUpdateData['receiveLimits.dailyUsed'] = 0.0;
        if (needsMonthlyReset) walletUpdateData['receiveLimits.monthlyUsed'] = 0.0;
      } else if (transaction.isReceive) {
        walletUpdateData['receiveLimits.dailyUsed'] = needsDailyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        walletUpdateData['receiveLimits.monthlyUsed'] = needsMonthlyReset
            ? transaction.amount
            : FieldValue.increment(transaction.amount);
        if (needsDailyReset) walletUpdateData['sendLimits.dailyUsed'] = 0.0;
        if (needsMonthlyReset) walletUpdateData['sendLimits.monthlyUsed'] = 0.0;
      }

      if (transaction.isSend || transaction.isReceive) {
        walletUpdateData['${FirebaseConstants.stats}.${transaction.isSend ? FirebaseConstants.totalSentAmount : FirebaseConstants.totalReceivedAmount}'] =
            FieldValue.increment(transaction.amount);
        walletUpdateData['${FirebaseConstants.stats}.${FirebaseConstants.totalCommission}'] =
            FieldValue.increment(transaction.commission);
      }

      // Commit Wallet Updates
      tx.update(walletRef, walletUpdateData);

      // Update Daily Stats Document
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

      debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
          'SUCCESS — all Firestore writes queued atomically for '
          'txId=${transaction.transactionId}');
    });
  }
}