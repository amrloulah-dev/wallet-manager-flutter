import 'package:flutter/foundation.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/transaction_validator_service.dart';

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
  Future<void> createTransaction(TransactionModel transaction) async {
    try {
      debugPrint('🔥 [TX_FLOW] [transaction_repository] -> createTransaction: '
          'RECEIVED | txId=${transaction.transactionId}, '
          'walletId=${transaction.walletId}, type=${transaction.transactionType}, '
          'amount=${transaction.amount}, commission=${transaction.commission}');
      debugPrint('🔥 [TX_FLOW] [transaction_repository] -> createTransaction: '
          'Delegating to TransactionValidatorService.validateAndSave ...');

      // Delegate entirely to the unified validator which handles
      // balance, stats, and daily_stats atomically inside runTransaction.
      await TransactionValidatorService().validateAndSave(transaction);
      debugPrint('🔥 [TX_FLOW] [transaction_repository] -> createTransaction: '
          'validateAndSave returned SUCCESS for txId=${transaction.transactionId}');

      // Handle debt stats separately (not covered by the validator)
      if (transaction.isDebt) {
        await _statsRepository.incrementOpenDebtStats(
            transaction.storeId, transaction.amount);
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
}
