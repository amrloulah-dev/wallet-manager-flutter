import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import '../models/wallet_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_helper.dart';
import '../models/transaction_model.dart';
import '../services/firebase_service.dart';

class TransactionRepository {
  final FirebaseService _firebaseService;
  final CacheManager _cacheManager;
  final StatsRepository _statsRepository;

  TransactionRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
    StatsRepository? statsRepository,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _cacheManager = cacheManager ?? CacheManager(),
        _statsRepository = statsRepository ?? StatsRepository();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  CollectionReference get _transactionsCollection =>
      _firestore.collection(FirebaseConstants.transactions);

  CollectionReference get transactionsCollection => _transactionsCollection;

  // 1️⃣ CREATE
  Future<void> createTransaction(TransactionModel transaction,
      {bool force = false}) async {
    try {
      final balanceChange = transaction.isSend
          ? -(transaction.amount + transaction.serviceFee)
          : transaction.amount;

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

        if (transaction.isSend) {
          if (validationWallet.balance < transaction.amount) {
            throw ValidationException(
                'المبلغ المراد إرساله أكبر من الرصيد المتاح.');
          }

          // New Validation Rules (Strict Implementation)
          // Rule 1: Transaction Cap
          if (transaction.amount > validationWallet.getLimits().dailyLimit) {
            _validateLimit(validationWallet, force,
                'المبلغ يتجاوز الحد الأقصى للمعاملة الواحدة.');
          }
          // Rule 3: Monthly Aggregate
          if (validationWallet.getLimits().monthlyUsed + transaction.amount >
              validationWallet.getLimits().monthlyLimit) {
            _validateLimit(
                validationWallet, force, 'تم تجاوز الحد الشهري لهذه المحفظة.');
          }
        } else if (transaction.isReceive) {
          // Rule 1: Transaction Cap
          if (transaction.amount >
              validationWallet.getReceiveLimits().dailyLimit) {
            _validateLimit(validationWallet, force,
                'المبلغ يتجاوز الحد الأقصى للمعاملة الواحدة.');
          }
          // Rule 3: Monthly Aggregate
          if (validationWallet.getReceiveLimits().monthlyUsed +
                  transaction.amount >
              validationWallet.getReceiveLimits().monthlyLimit) {
            _validateLimit(
                validationWallet, force, 'تم تجاوز الحد الشهري لهذه المحفظة.');
          }
        }

        final txRef = _transactionsCollection.doc(transaction.transactionId);
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

      // Update summary stats after the main transaction succeeds
      if (!transaction.isDeposit) {
        await _statsRepository.updateStatsOnTransactionCreate(
            transaction.storeId, transaction);
        await _statsRepository.updateStatsOnWalletChange(transaction.storeId,
            balanceChange: balanceChange);
        if (transaction.isDebt) {
          await _statsRepository.incrementOpenDebtStats(
              transaction.storeId, transaction.amount);
        }
      } else {
        await _statsRepository.updateStatsOnWalletChange(transaction.storeId,
            balanceChange: transaction.amount);
      }

      _cacheManager.clearWhere((key) => key.startsWith('transactions_page_0_'));
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_0_'));
      _cacheManager.clear('wallet_details_${transaction.walletId}');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create transaction: ${e.message}',
          code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
          'An unexpected error occurred while creating the transaction.');
    }
  }

  // 2️⃣ READ
  Future<TransactionModel?> getTransactionById(String transactionId) async {
    final cacheKey = 'transaction_details_$transactionId';
    final cachedTx = _cacheManager.get<TransactionModel>(cacheKey);
    if (cachedTx != null) return cachedTx;

    try {
      final doc = await _transactionsCollection.doc(transactionId).get();
      if (!doc.exists) return null;
      final tx = TransactionModel.fromFirestore(doc);
      _cacheManager.set(cacheKey, tx, duration: const Duration(minutes: 10));
      return tx;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get transaction: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching the transaction.');
    }
  }

  Future<Map<String, dynamic>> getTransactionsByDateRangePaginated(
    String storeId,
    DateTime startDate,
    DateTime endDate, {
    String? transactionType,
    int limit = 15,
    DocumentSnapshot? lastDoc,
  }) async {
    final cacheKey =
        'transactions_page_0_${storeId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}_$transactionType';
    if (lastDoc == null) {
      final cachedResult = _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) return cachedResult;
    }

    try {
      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('transactionDate',
              isGreaterThanOrEqualTo: DateHelper.getStartOfDay(startDate))
          .where('transactionDate',
              isLessThanOrEqualTo: DateHelper.getEndOfDay(endDate))
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true);

      if (transactionType != null) {
        query = query.where('transactionType', isEqualTo: transactionType);
      }

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.limit(limit).get();
      final transactions = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      final result = {
        'transactions': transactions,
        'lastDoc': newLastDoc,
      };

      if (lastDoc == null) {
        _cacheManager.set(cacheKey, result);
      }

      return result;
    } on FirebaseException catch (e) {
      throw ServerException(
          'Failed to get paginated transactions: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching paginated transactions.');
    }
  }

  Future<List<TransactionModel>> getTransactionsByDateRange(
      String storeId, DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('transactionDate',
              isGreaterThanOrEqualTo: DateHelper.getStartOfDay(startDate))
          .where('transactionDate',
              isLessThanOrEqualTo: DateHelper.getEndOfDay(endDate))
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException(
          'Failed to get transactions by date range: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching transactions.');
    }
  }

  // 3️⃣ UPDATE
  Future<void> updateTransaction(
      String transactionId, Map<String, dynamic> data) async {
    try {
      final updateData = {
        ...data,
        FirebaseConstants.updatedAt: Timestamp.now()
      };
      await _transactionsCollection.doc(transactionId).update(updateData);
      _cacheManager.clearWhere((key) => key.startsWith('transactions_page_0_'));
      _cacheManager.clear('transaction_details_$transactionId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update transaction: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while updating the transaction.');
    }
  }

  // 4️⃣ DELETE
  Future<void> deleteTransaction(String transactionId, String deletedBy) async {
    try {
      await _transactionsCollection.doc(transactionId).update({
        'isDeleted': true,
        'deletedAt': Timestamp.now(),
        'deletedBy': deletedBy,
      });
      _cacheManager.clearWhere((key) => key.startsWith('transactions_page_0_'));
      _cacheManager.clear('transaction_details_$transactionId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete transaction: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while deleting the transaction.');
    }
  }

  Future<List<TransactionModel>> getAllTransactions(String storeId) async {
    try {
      final snapshot = await _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('isDeleted', isEqualTo: false)
          .get();
      return snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get all transactions: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching all transactions.');
    }
  }

  Future<Map<String, dynamic>> getTransactionAggregates(String storeId,
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('isDeleted', isEqualTo: false);

      if (startDate != null) {
        query =
            query.where('transactionDate', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('transactionDate', isLessThanOrEqualTo: endDate);
      }

      final sendQuery = query.where('transactionType', isEqualTo: 'send');
      final receiveQuery = query.where('transactionType', isEqualTo: 'receive');

      final sendSnapshot = await sendQuery.get();
      final receiveSnapshot = await receiveQuery.get();

      double manualTotalSent = 0;
      double manualTotalSentCommission = 0;
      int manualSendCount = 0;
      for (var doc in sendSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final commission = (data['commission'] ?? 0).toDouble();
        manualTotalSent += amount;
        manualTotalSentCommission += commission;
        manualSendCount++;
      }

      double manualTotalReceived = 0;
      double manualTotalReceiveCommission = 0;
      int manualReceiveCount = 0;
      for (var doc in receiveSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final amount = (data['amount'] ?? 0).toDouble();
        final commission = (data['commission'] ?? 0).toDouble();
        manualTotalReceived += amount;
        manualTotalReceiveCommission += commission;
        manualReceiveCount++;
      }

      return {
        'totalTransactions': manualSendCount + manualReceiveCount,
        'totalCommission':
            manualTotalSentCommission + manualTotalReceiveCommission,
        'sendCount': manualSendCount,
        'totalSentAmount': manualTotalSent,
        'receiveCount': manualReceiveCount,
        'totalReceivedAmount': manualTotalReceived,
      };
    } catch (e) {
      // On any error, return a zero-map to prevent breaking the UI.
      return {
        'totalTransactions': 0,
        'totalCommission': 0.0,
        'sendCount': 0,
        'totalSendAmount': 0.0,
        'receiveCount': 0,
        'totalReceivedAmount': 0.0,
      };
    }
  }

  void _validateLimit(WalletModel wallet, bool force, String message) {
    if (wallet.walletType == 'instapay') {
      if (!force) {
        throw LimitExceededWarning(message);
      }
      // If force is true, allow bypassing the limit.
    } else {
      // For other wallets (and strictly enforced limits), throw ValidationException.
      throw ValidationException(message);
    }
  }
}
