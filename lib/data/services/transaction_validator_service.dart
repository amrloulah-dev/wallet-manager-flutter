import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import '../../core/utils/amount_validator.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_helper.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

import 'package:walletmanager/core/di/service_locator.dart';

class TransactionValidatorService {
  // Currency-aware epsilon for EGP (Egyptian Pound)
  // Minimum unit: 0.01 EGP (1 fils)
  static const double _epsilonEGP = 0.01;

  final FirebaseFirestore _firestore;

  TransactionValidatorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseFirestore>();

  Future<void> validateAndSave(TransactionModel transaction) async {
    debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> validateAndSave: '
        'ENTRY | txId=${transaction.transactionId}, walletId=${transaction.walletId}, '
        'type=${transaction.transactionType}, amount=${transaction.amount}, '
        'serviceFee=${transaction.serviceFee}, commission=${transaction.commission}, '
        'storeId=${transaction.storeId}');

    // 1. Positive Amount Check
    AmountValidator.ensurePositive(transaction.amount);
    // Ensure commission and serviceFee are not negative
    AmountValidator.ensurePositiveOrZero(transaction.commission);
    AmountValidator.ensurePositiveOrZero(transaction.serviceFee);

    final balanceChange = transaction.isSend
        ? -(transaction.amount + transaction.serviceFee)
        : (transaction.amount + transaction.commission);

    // Wrap the successful validation states inside FirebaseFirestore.instance.runTransaction()
    await _firestore.runTransaction<void>((tx) async {
      final walletRef = _firestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(transaction.walletId);
      final walletSnap = await tx.get(walletRef);
      if (!walletSnap.exists) throw NotFoundException('المحفظة غير موجودة.');

      var wallet = WalletModel.fromFirestore(walletSnap);

      // Bug B-004: Prevent transactions on logically deleted/inactive wallets
      if (!wallet.isActive) {
        throw ValidationException('لا يمكن إجراء معاملة: المحفظة غير مفعلة أو تم حذفها');
      }

      // Handle simple deposit immediately
      if (transaction.isDeposit) {
        tx.update(
            walletRef, {'balance': FieldValue.increment(transaction.amount)});
        return;
      }

      final now = Timestamp.now();

      // ------------------------------------------------------------------
      // ATOMIC LIMIT RESET LOGIC
      // ------------------------------------------------------------------
      // We check if resets are needed using the fresh wallet data from the transaction
      final bool needsDailyReset = wallet.needsDailyReset;
      final bool needsMonthlyReset = wallet.needsMonthlyReset;
      
      var validationWallet = wallet;
      if (needsDailyReset) {
        validationWallet = validationWallet.copyWith(
          lastDailyReset: now.toDate(),
          sendLimits: validationWallet.sendLimits.copyWith(dailyUsed: 0),
          receiveLimits: validationWallet.receiveLimits.copyWith(dailyUsed: 0),
        );
      }
      if (needsMonthlyReset) {
        validationWallet = validationWallet.copyWith(
          lastMonthlyReset: now.toDate(),
          sendLimits: validationWallet.sendLimits.copyWith(monthlyUsed: 0),
          receiveLimits: validationWallet.receiveLimits.copyWith(monthlyUsed: 0),
        );
      }

      debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
          'walletFetched | walletId=${wallet.walletId}, '
          'walletType=${wallet.walletType}, currentBalance=${wallet.balance}, '
          'balanceChange=$balanceChange');

      // ------------------------------------------------------------------
      // 2. EXPLICIT NETWORK LIMITS (InstaPay / Telecom) - Single Transaction
      // ------------------------------------------------------------------
      final isInstaPay = wallet.walletType == WalletType.instaPay;
      final isTelecom = [
        WalletType.vodafoneCash,
        WalletType.orangeCash,
        WalletType.etisalatCash,
        WalletType.wePay
      ].contains(wallet.walletType);

      if (isInstaPay && transaction.amount > 70000) {
        throw ValidationException('الحد الأقصى للمعاملة الواحدة لإنستاباي هو 70,000 جنيه.');
      }
      if (isTelecom && transaction.amount > 60000) {
        throw ValidationException('الحد الأقصى للمعاملة الواحدة للمحافظ الإلكترونية هو 60,000 جنيه.');
      }

       // ------------------------------------------------------------------
       // 3. CORE RULE: Balance Sufficiency Check (with Currency-Aware Epsilon)
       // ------------------------------------------------------------------
       if (transaction.isSend) {
         final totalDeduction = transaction.amount + transaction.serviceFee;
         
         debugPrint('🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
             'BALANCE CHECK | balance=${validationWallet.balance}, '
             'totalDeduction=$totalDeduction');
             
         if (validationWallet.balance < (totalDeduction - _epsilonEGP)) {
           throw ValidationException('المبلغ المراد إرساله (مع العمولة) أكبر من الرصيد المتاح.');
         }
       }

      // ------------------------------------------------------------------
      // 4. CUMULATIVE LIMITS (InstaPay & General Capacity)
      // ------------------------------------------------------------------
      if (isInstaPay) {
        num usedAmount = transaction.isSend
            ? validationWallet.sendLimits.dailyUsed
            : validationWallet.receiveLimits.dailyUsed;
            
        if (usedAmount + transaction.amount > 120000) {
          throw ValidationException('تم تجاوز الحد اليومي لمحفظة InstaPay (120,000 جنيه).');
        }
      }

      if (transaction.isSend) {
        if (validationWallet.sendLimits.dailyUsed + transaction.amount > validationWallet.getLimits().dailyLimit) {
          throw ValidationException('تم تجاوز الحد اليومي للإرسال لهذه المحفظة.');
        }
        if (validationWallet.sendLimits.monthlyUsed + transaction.amount > validationWallet.getLimits().monthlyLimit) {
          throw ValidationException('تم تجاوز الحد الشهري للإرسال لهذه المحفظة.');
        }
      } else if (transaction.isReceive) {
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

      // Calculate NEW balance in memory to avoid FieldValue.increment testing issues
      // and ensure precision control.
      walletUpdateData['balance'] = validationWallet.balance + balanceChange;
      
      walletUpdateData['${FirebaseConstants.stats}.${FirebaseConstants.totalTransactions}'] = FieldValue.increment(1);
      walletUpdateData['${FirebaseConstants.stats}.${FirebaseConstants.lastTransactionDate}'] = now;

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

      // Update Store Stats Summary Document
      final statsSummaryRef = _firestore
          .collection('stores')
          .doc(transaction.storeId)
          .collection('stats')
          .doc('summary');

      final Map<String, dynamic> summaryUpdates = {
        'totalTransactions': FieldValue.increment(1),
        'totalTransactionsToday': FieldValue.increment(1),
        'totalCommission': FieldValue.increment(transaction.commission),
        'totalCommissionToday': FieldValue.increment(transaction.commission),
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (transaction.isSend) {
        summaryUpdates['sendCount'] = FieldValue.increment(1);
        summaryUpdates['totalSentAmount'] = FieldValue.increment(transaction.amount);
      } else if (transaction.isReceive) {
        summaryUpdates['receiveCount'] = FieldValue.increment(1);
        summaryUpdates['totalReceivedAmount'] = FieldValue.increment(transaction.amount);
      }

      tx.set(statsSummaryRef, summaryUpdates, SetOptions(merge: true));

      // Update Store Document's root stats field (Legacy support)
      final storeRef = _firestore.collection('stores').doc(transaction.storeId);
      tx.update(storeRef, {
        'stats.totalTransactionsToday': FieldValue.increment(1),
        'stats.totalCommissionToday': FieldValue.increment(transaction.commission),
        'stats.lastUpdated': FieldValue.serverTimestamp(),
      });

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
