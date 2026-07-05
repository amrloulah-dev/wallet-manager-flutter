import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import '../../core/utils/amount_validator.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/utils/date_helper.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';

import '../models/platform_settings_model.dart';
import '../../core/utils/number_formatter.dart';

import 'package:walletmanager/core/di/service_locator.dart';

class TransactionValidatorService {
  // Currency-aware epsilon for EGP (Egyptian Pound)
  // Minimum unit: 0.01 EGP (1 fils)
  static const double _epsilonEGP = 0.01;

  final FirebaseFirestore _firestore;

  TransactionValidatorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseFirestore>();

  Future<void> validateAndSave(
    TransactionModel transaction,
    PlatformSettingsModel settings,
    {Future<void> Function(Transaction)? extraWrites}
  ) async {
    try {
      if (kDebugMode) {
        debugPrint(
            '🔥 [TX_FLOW] [transaction_validator_service] -> validateAndSave: '
            'ENTRY | txId=${transaction.transactionId}, walletId=${transaction.walletId}, '
            'type=${transaction.transactionType}, amount=${transaction.amount}, '
            'serviceFee=${transaction.serviceFee}, commission=${transaction.commission}, '
            'storeId=${transaction.storeId}');
      }

      // 1. Positive Amount Check
      AmountValidator.ensurePositive(transaction.amount);
      // Ensure commission and serviceFee are not negative
      AmountValidator.ensurePositiveOrZero(transaction.commission);
      AmountValidator.ensurePositiveOrZero(transaction.serviceFee);

      final balanceChange = transaction.isSend
          ? -(transaction.amount + transaction.serviceFee)
          : (transaction.isReceive
              ? transaction
                  .amount // Phase 1.4: Receive is amount only (omitting commission)
              : (transaction.amount +
                  transaction
                      .commission)); // Default for other types (e.g. deposit)

      // Wrap the successful validation states inside FirebaseFirestore.instance.runTransaction()
      await _firestore.runTransaction<void>((tx) async {
        final walletRef = _firestore
            .collection(FirebaseConstants.walletsCollection)
            .doc(transaction.walletId);
        final walletSnap = await tx.get(walletRef);
        if (!walletSnap.exists) {
          throw NotFoundException('wallet_error_not_found');
        }

        var wallet = WalletModel.fromFirestore(walletSnap);

        // Bug B-004: Prevent transactions on logically deleted/inactive wallets
        if (!wallet.isActive) {
          throw ValidationException('wallet_error_inactive');
        }

        final now = DateTime.now();

        // ------------------------------------------------------------------
        // ATOMIC LIMIT RESET LOGIC
        // ------------------------------------------------------------------
        // We check if resets are needed using the fresh wallet data from the transaction
        final bool needsDailyReset = wallet.needsDailyReset;
        final bool needsMonthlyReset = wallet.needsMonthlyReset;

        var validationWallet = wallet;
        if (needsDailyReset) {
          validationWallet = validationWallet.copyWith(
            lastDailyReset: now,
            sendLimits: validationWallet.sendLimits.copyWith(dailyUsed: 0),
            receiveLimits:
                validationWallet.receiveLimits.copyWith(dailyUsed: 0),
          );
        }
        if (needsMonthlyReset) {
          validationWallet = validationWallet.copyWith(
            lastMonthlyReset: now,
            sendLimits: validationWallet.sendLimits.copyWith(monthlyUsed: 0),
            receiveLimits:
                validationWallet.receiveLimits.copyWith(monthlyUsed: 0),
          );
        }

        if (kDebugMode) {
          debugPrint(
              '🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
              'walletFetched | walletId=${wallet.walletId}, '
              'walletType=${wallet.walletType}, currentBalance=${wallet.balance}, '
              'balanceChange=$balanceChange');
        }

        // ------------------------------------------------------------------
        // 2. EXPLICIT NETWORK LIMITS (InstaPay / Telecom) - Single Transaction
        // ------------------------------------------------------------------
        final isInstaPay = validationWallet.walletType == WalletType.instaPay;
        final dynamicLimits = validationWallet.getDynamicNetworkLimits(settings);

        if (transaction.amount > dynamicLimits.maxPerTransaction) {
          if (isInstaPay) {
            throw ValidationException('wallet_error_instapay_limit:${NumberFormatter.formatAmount(dynamicLimits.maxPerTransaction)}');
          } else {
            throw ValidationException('wallet_error_telecom_limit:${NumberFormatter.formatAmount(dynamicLimits.maxPerTransaction)}');
          }
        }

        // ------------------------------------------------------------------
        // 3. CORE RULE: Balance Sufficiency Check (with Currency-Aware Epsilon)
        // ------------------------------------------------------------------
        if (transaction.isSend) {
          final totalDeduction = transaction.amount + transaction.serviceFee;

          if (kDebugMode) {
            debugPrint(
                '🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
                'BALANCE CHECK | balance=${validationWallet.balance}, '
                'totalDeduction=$totalDeduction');
          }

          if ((validationWallet.balance + _epsilonEGP) < totalDeduction) {
            throw ValidationException('wallet_error_insufficient_balance');
          }
        }

        // ------------------------------------------------------------------
        // 4. CUMULATIVE LIMITS (InstaPay & General Capacity)
        // ------------------------------------------------------------------
        if (transaction.isSend) {
          if (validationWallet.sendLimits.dailyUsed + transaction.amount > dynamicLimits.dailySend) {
            if (isInstaPay) {
              throw ValidationException('wallet_error_instapay_daily_limit:${NumberFormatter.formatAmount(dynamicLimits.dailySend)}');
            }
            throw ValidationException('wallet_error_daily_send_limit');
          }
          if (validationWallet.sendLimits.monthlyUsed + transaction.amount > dynamicLimits.monthlySend) {
            throw ValidationException('wallet_error_monthly_send_limit');
          }
        } else if (transaction.isReceive) {
          if (validationWallet.receiveLimits.dailyUsed + transaction.amount > dynamicLimits.dailyReceive) {
            if (isInstaPay) {
              throw ValidationException('wallet_error_instapay_daily_limit:${NumberFormatter.formatAmount(dynamicLimits.dailyReceive)}');
            }
            throw ValidationException('wallet_error_daily_receive_limit');
          }
          if (validationWallet.receiveLimits.monthlyUsed + transaction.amount > dynamicLimits.monthlyReceive) {
            throw ValidationException('wallet_error_monthly_receive_limit');
          }
        }

        // ------------------------------------------------------------------
        // 5. DATABASE WRITES (Atomic execution)
        // ------------------------------------------------------------------

        // Save Transaction Document
        final txRef = _firestore
            .collection(FirebaseConstants.transactions)
            .doc(transaction.transactionId);
        final txData = transaction.toFirestore();
        txData[FirebaseConstants.createdAt] = FieldValue.serverTimestamp();
        txData['transactionDate'] = FieldValue.serverTimestamp();
        tx.set(txRef, txData);

        // Prepare Wallet Updates
        final Map<String, dynamic> walletUpdateData = {};

        // Use atomic increment for balance update
        walletUpdateData['balance'] = FieldValue.increment(balanceChange);

        walletUpdateData[
                '${FirebaseConstants.stats}.${FirebaseConstants.totalTransactions}'] =
            FieldValue.increment(1);
        walletUpdateData[
                '${FirebaseConstants.stats}.${FirebaseConstants.lastTransactionDate}'] =
            FieldValue.serverTimestamp();

        if (needsDailyReset) {
          walletUpdateData[FirebaseConstants.lastDailyReset] =
              FieldValue.serverTimestamp();
        }
        if (needsMonthlyReset) {
          walletUpdateData[FirebaseConstants.lastMonthlyReset] =
              FieldValue.serverTimestamp();
        }

        if (transaction.isSend) {
          walletUpdateData['${FirebaseConstants.sendLimits}.dailyUsed'] =
              needsDailyReset
                  ? transaction.amount
                  : FieldValue.increment(transaction.amount);
          walletUpdateData['${FirebaseConstants.sendLimits}.monthlyUsed'] =
              needsMonthlyReset
                  ? transaction.amount
                  : FieldValue.increment(transaction.amount);

          if (needsDailyReset) {
            walletUpdateData['${FirebaseConstants.receiveLimits}.dailyUsed'] =
                0.0;
          }
          if (needsMonthlyReset) {
            walletUpdateData['${FirebaseConstants.receiveLimits}.monthlyUsed'] =
                0.0;
          }
        } else if (transaction.isReceive) {
          walletUpdateData['${FirebaseConstants.receiveLimits}.dailyUsed'] =
              needsDailyReset
                  ? transaction.amount
                  : FieldValue.increment(transaction.amount);
          walletUpdateData['${FirebaseConstants.receiveLimits}.monthlyUsed'] =
              needsMonthlyReset
                  ? transaction.amount
                  : FieldValue.increment(transaction.amount);

          if (needsDailyReset) {
            walletUpdateData['${FirebaseConstants.sendLimits}.dailyUsed'] = 0.0;
          }
          if (needsMonthlyReset) {
            walletUpdateData['${FirebaseConstants.sendLimits}.monthlyUsed'] =
                0.0;
          }
        }

        if (transaction.isSend || transaction.isReceive) {
          walletUpdateData[
                  '${FirebaseConstants.stats}.${transaction.isSend ? FirebaseConstants.totalSentAmount : FirebaseConstants.totalReceivedAmount}'] =
              FieldValue.increment(transaction.amount);
          walletUpdateData[
                  '${FirebaseConstants.stats}.${FirebaseConstants.totalCommission}'] =
              FieldValue.increment(transaction.commission);
          // Phase 1.4: Track totalServiceFee in wallet stats
          walletUpdateData['${FirebaseConstants.stats}.totalServiceFee'] =
              FieldValue.increment(transaction.serviceFee);
        }

        // Commit Wallet Updates
        tx.update(walletRef, walletUpdateData);

        // Update Store Stats Summary Document
        final statsSummaryRef = _firestore
            .doc(FirebaseConstants.statsSummaryPath(transaction.storeId));

        final Map<String, dynamic> summaryUpdates = {
          FirebaseConstants.totalTransactions: FieldValue.increment(1),
          FirebaseConstants.totalTransactionsToday: FieldValue.increment(1),
          FirebaseConstants.totalCommission:
              FieldValue.increment(transaction.commission),
          FirebaseConstants.totalCommissionToday:
              FieldValue.increment(transaction.commission),
          FirebaseConstants.totalServiceFee:
              FieldValue.increment(transaction.serviceFee),
          FirebaseConstants.totalServiceFeeToday:
              FieldValue.increment(transaction.serviceFee),
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (transaction.isSend) {
          summaryUpdates['sendCount'] = FieldValue.increment(1);
          summaryUpdates[FirebaseConstants.totalSentAmount] =
              FieldValue.increment(transaction.amount);
          summaryUpdates[FirebaseConstants.totalSentAmountToday] =
              FieldValue.increment(transaction.amount);
        } else if (transaction.isReceive) {
          summaryUpdates['receiveCount'] = FieldValue.increment(1);
          summaryUpdates[FirebaseConstants.totalReceivedAmount] =
              FieldValue.increment(transaction.amount);
          summaryUpdates[FirebaseConstants.totalReceivedAmountToday] =
              FieldValue.increment(transaction.amount);
        }

        tx.set(statsSummaryRef, summaryUpdates, SetOptions(merge: true));

        // Update Daily Stats Document
        final dailyStatsRef = _firestore.doc(FirebaseConstants.dailyStatsPath(
            transaction.storeId, DateHelper.getCurrentDateString()));

        final Map<String, dynamic> dailyStatsUpdates = {
          'transactionCount': FieldValue.increment(1),
          FirebaseConstants.totalCommission:
              FieldValue.increment(transaction.commission),
          'totalServiceFee': FieldValue.increment(transaction.serviceFee),
          'totalAmount': FieldValue.increment(transaction.amount),
        };

        if (transaction.isSend) {
          dailyStatsUpdates['sendCount'] = FieldValue.increment(1);
          dailyStatsUpdates['totalSentAmount'] =
              FieldValue.increment(transaction.amount);
        } else if (transaction.isReceive) {
          dailyStatsUpdates['receiveCount'] = FieldValue.increment(1);
          dailyStatsUpdates['totalReceivedAmount'] =
              FieldValue.increment(transaction.amount);
        }

        tx.set(
          dailyStatsRef,
          dailyStatsUpdates,
          SetOptions(merge: true),
        );

        // ------------------------------------------------------------------
        // 6. EXTRA WRITES (Provided by caller)
        // ------------------------------------------------------------------
        if (extraWrites != null) {
          await extraWrites(tx);
        }

        if (kDebugMode) {
          debugPrint(
              '🔥 [TX_FLOW] [transaction_validator_service] -> runTransaction: '
              'SUCCESS — all Firestore writes queued atomically for '
              'txId=${transaction.transactionId}');
        }
      });
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'TransactionValidatorService.validateAndSave',
      );
      throw ServerException('wallet_error_transaction_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'TransactionValidatorService.validateAndSave',
      );
      if (e is AppException) rethrow;
      throw ServerException('wallet_error_transaction_failed');
    }
  }
}
