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
import '../models/paginated_result.dart';

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

  String generateId() => _transactionsCollection.doc().id;

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
  Stream<List<TransactionModel>> getTransactionsStream(
    String storeId,
    DateTime startDate,
    DateTime endDate, {
    String? transactionType,
    int limit = 20,
  }) {
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

      return query.limit(limit).snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList();
      });
    } catch (e) {
      return Stream.error(ServerException('فشل الحصول على تيار المعاملات: $e'));
    }
  }

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
  Future<PaginatedResult<TransactionModel>> getTransactionsByDateRange(
      String storeId, DateTime startDate, DateTime endDate, {DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('transactionDate',
              isGreaterThanOrEqualTo: DateHelper.getStartOfDay(startDate))
          .where('transactionDate',
              isLessThanOrEqualTo: DateHelper.getEndOfDay(endDate))
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(20).get();
      final items = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      
      return PaginatedResult(items: items, lastDocument: lastDoc);
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

  Future<PaginatedResult<TransactionModel>> getAllTransactions(String storeId, {DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('isDeleted', isEqualTo: false);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(20).get();
      final items = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PaginatedResult(items: items, lastDocument: lastDoc);
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get all transactions: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching all transactions.');
    }
  }
}
