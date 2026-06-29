import 'package:walletmanager/core/enums/transaction_enums.dart';
import '../../core/utils/amount_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/date_helper.dart';
import '../models/paginated_result.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/firebase_service.dart';

import 'package:walletmanager/core/di/service_locator.dart';

class TransactionRepository {
  final FirebaseService _firebaseService;
  final CacheManager _cacheManager;

  final FirebaseFirestore? _customFirestore;

  TransactionRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
    StatsRepository? statsRepository,
    FirebaseFirestore? firestore,
  })  : _firebaseService = firebaseService ?? sl<FirebaseService>(),
        _cacheManager = cacheManager ?? sl<CacheManager>(),
        _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? _firebaseService.firestore;
  CollectionReference get _transactionsCollection =>
      _firestore.collection(FirebaseConstants.transactions);

  String generateId() => _transactionsCollection.doc().id;

  // 1️⃣ CREATE

  /// Creates a deposit transaction from primitive Dart types.
  /// [Timestamp] stamps are applied here, keeping infrastructure types
  /// out of the providers layer (STRICT CLEAN ARCHITECTURE).
  Future<void> createDeposit({
    required String transactionId,
    required String storeId,
    required String walletId,
    required double amount,
    required String createdBy,
  }) async {
    AmountValidator.ensurePositive(amount);
    final now = DateTime.now();
    final transaction = TransactionModel(
      transactionId: transactionId,
      storeId: storeId,
      walletId: walletId,
      transactionType: TransactionType.deposit, // ENUM refactor
      amount: amount,
      transactionDate: now,
      createdAt: now,
      createdBy: createdBy,
    );
    return createTransaction(transaction);
  }

  Future<void> createTransaction(TransactionModel transaction) async {
    AmountValidator.ensurePositive(transaction.amount);
    try {
      if (kDebugMode) {
        debugPrint(
            '🔥 [TX_FLOW] [transaction_repository] -> createTransaction: '
            'RECEIVED | txId=${transaction.transactionId}, '
            'walletId=${transaction.walletId}, type=${transaction.transactionType}');
      }

      final walletRef = _firestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(transaction.walletId);
      final walletSnap = await walletRef.get();
      if (!walletSnap.exists) {
        throw NotFoundException('wallet_error_not_found');
      }

      final wallet = WalletModel.fromFirestore(walletSnap);
      if (!wallet.isActive) {
        throw ValidationException('wallet_error_inactive');
      }

      final needsDailyReset = wallet.needsDailyReset;
      final needsMonthlyReset = wallet.needsMonthlyReset;

      final balanceChange = transaction.isSend
          ? -(transaction.amount + transaction.serviceFee)
          : (transaction.isReceive
              ? transaction.amount
              : (transaction.amount + transaction.commission));

      final batch = _firestore.batch();

      // 1. Save Transaction Document
      final txRef = _transactionsCollection.doc(transaction.transactionId);
      final txData = transaction.toFirestore();
      txData[FirebaseConstants.createdAt] = FieldValue.serverTimestamp();
      txData['transactionDate'] = FieldValue.serverTimestamp();
      batch.set(txRef, txData);

      // 2. Prepare Wallet Updates
      final Map<String, dynamic> walletUpdateData = {};
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
          walletUpdateData['${FirebaseConstants.sendLimits}.monthlyUsed'] = 0.0;
        }
      }

      if (transaction.isSend || transaction.isReceive) {
        walletUpdateData[
                '${FirebaseConstants.stats}.${transaction.isSend ? FirebaseConstants.totalSentAmount : FirebaseConstants.totalReceivedAmount}'] =
            FieldValue.increment(transaction.amount);
        walletUpdateData[
                '${FirebaseConstants.stats}.${FirebaseConstants.totalCommission}'] =
            FieldValue.increment(transaction.commission);
        walletUpdateData['${FirebaseConstants.stats}.totalServiceFee'] =
            FieldValue.increment(transaction.serviceFee);
      }

      batch.update(walletRef, walletUpdateData);

      // 3. Update Store Stats Summary Document
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

      batch.set(statsSummaryRef, summaryUpdates, SetOptions(merge: true));

      // 4. Update Daily Stats Document
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

      batch.set(
        dailyStatsRef,
        dailyStatsUpdates,
        SetOptions(merge: true),
      );

      // 4.1 Update Global Stats (totalTransactions counter)
      final globalStatsRef = _firestore.doc(FirebaseConstants.globalStatsPath(transaction.storeId));
      batch.set(
        globalStatsRef,
        {FirebaseConstants.totalTransactions: FieldValue.increment(1)},
        SetOptions(merge: true),
      );

      // 5. Extra Writes (Debt increment)
      if (transaction.isDebt) {
        final Map<String, dynamic> debtSummaryUpdates = {
          'openDebtsCount': FieldValue.increment(1),
          'totalOpenAmount': FieldValue.increment(transaction.amount),
          'lastUpdated': FieldValue.serverTimestamp(),
        };
        batch.set(statsSummaryRef, debtSummaryUpdates, SetOptions(merge: true));

        final Map<String, dynamic> debtDailyUpdates = {
          'openDebtsCount': FieldValue.increment(1),
          'totalOpenAmount': FieldValue.increment(transaction.amount),
        };
        batch.set(dailyStatsRef, debtDailyUpdates, SetOptions(merge: true));
      }

      await batch.commit();

      _cacheManager.clearWhere((key) => key.startsWith('transactions_page_'));
      _cacheManager.clearWhere((key) => key.startsWith('wallets_page_'));
      _cacheManager.clear('wallet_details_${transaction.walletId}');
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.createTransaction');
      throw ServerException('transaction_error_create_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.createTransaction');
      if (e is AppException) rethrow;
      throw ServerException('transaction_error_create_failed');
    }
  }

  // 2️⃣ READ
  Stream<List<TransactionModel>> getTransactionsStream(
    String storeId,
    DateTime startDate,
    DateTime endDate, {
    TransactionType? transactionType, // ENUM refactor
    int limit = 20,
  }) {
    try {
      final startTimestamp =
          Timestamp.fromDate(DateHelper.getStartOfDay(startDate));
      final endTimestamp = Timestamp.fromDate(DateHelper.getEndOfDay(endDate));

      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('transactionDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('transactionDate', isLessThanOrEqualTo: endTimestamp)
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true);

      if (transactionType != null) {
        query = query.where('transactionType', isEqualTo: transactionType.name);
      }

      return query.limit(limit).snapshots().map((snapshot) {
        final items = <TransactionModel>[];
        for (final doc in snapshot.docs) {
          try {
            items.add(TransactionModel.fromFirestore(doc));
          } catch (e, stack) {
            AppErrorHandler.logSilentError(
                'Malformed tx doc in stream: ${doc.id} | error: $e',
                'transaction_stream_corruption',
                stackTrace: stack);
          }
        }
        return items;
      }).handleError((error, stack) {
        AppErrorHandler.logSilentError(
            error.toString(), 'TransactionRepository.getTransactionsStream',
            stackTrace: stack);
        throw error;
      });
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
          e.toString(), 'TransactionRepository.getTransactionsStream',
          stackTrace: stack);
      return Stream.error(ServerException('transaction_error_stream_failed'));
    }
  }

  Future<TransactionModel?> getTransactionById(String transactionId,
      {String? expectedStoreId}) async {
    final cacheKey = 'transaction_details_$transactionId';
    final cachedTx = _cacheManager.get<TransactionModel>(cacheKey);

    if (cachedTx != null) {
      if (expectedStoreId != null && cachedTx.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }
      return cachedTx;
    }

    try {
      final doc = await _transactionsCollection.doc(transactionId).get();
      if (!doc.exists) return null;
      final tx = TransactionModel.fromFirestore(doc);

      // Post-fetch Tenant Isolation Guard (Report 2: M-5)
      if (expectedStoreId != null && tx.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }

      _cacheManager.set(cacheKey, tx, duration: const Duration(minutes: 10));
      return tx;
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.logSilentError(
          e.toString(), 'TransactionRepository.getTransactionById',
          stackTrace: stack);
      throw ServerException('transaction_error_fetch_failed', code: e.code);
    } catch (e, stack) {
      if (e is AppException) rethrow;
      AppErrorHandler.logSilentError(
          e.toString(), 'TransactionRepository.getTransactionById',
          stackTrace: stack);
      throw ServerException('transaction_error_fetch_failed');
    }
  }

  /// Fetches transactions within a date range with explicit pagination.
  /// Phase 4: Made stateless by requiring [lastDocument] parameter.
  Future<PaginatedResult<TransactionModel>> getTransactionsByDateRange(
      String storeId, DateTime startDate, DateTime endDate,
      {DocumentSnapshot? lastDocument}) async {
    try {
      final startTimestamp =
          Timestamp.fromDate(DateHelper.getStartOfDay(startDate));
      final endTimestamp = Timestamp.fromDate(DateHelper.getEndOfDay(endDate));

      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('transactionDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('transactionDate', isLessThanOrEqualTo: endTimestamp)
          .where('isDeleted', isEqualTo: false)
          .orderBy('transactionDate', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(20).get();
      final items = <TransactionModel>[];
      for (final doc in snapshot.docs) {
        try {
          items.add(TransactionModel.fromFirestore(doc));
        } catch (e, stack) {
          AppErrorHandler.logSilentError(
              'Malformed tx doc in date range list: ${doc.id} | error: $e',
              'transaction_date_list_corruption',
              stackTrace: stack);
        }
      }

      return PaginatedResult(
        items: items,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.getTransactionsByDateRange');
      throw ServerException('transaction_error_fetch_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.getTransactionsByDateRange');
      throw ServerException('transaction_error_fetch_failed');
    }
  }

  // 3️⃣ UPDATE
  Future<void> updateTransaction(
      String transactionId, Map<String, dynamic> data) async {
    // Domain Integrity Guard (Report 2: M-6)
    assert(!data.containsKey(FirebaseConstants.storeId),
        'storeId mutation is strictly forbidden for security reasons.');

    try {
      final updateData = {
        ...data,
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp()
      };
      await _transactionsCollection.doc(transactionId).update(updateData);
      _cacheManager.clearWhere((key) => key.startsWith('transactions_page_'));
      _cacheManager.clear('transaction_details_$transactionId');
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.updateTransaction');
      throw ServerException('transaction_error_update_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.updateTransaction');
      throw ServerException('transaction_error_update_failed');
    }
  }

  // 4️⃣ DELETE
  Future<void> deleteTransaction(String transactionId, String deletedBy) async {
    try {
      await _transactionsCollection.doc(transactionId).update({
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': deletedBy,
      });
      _cacheManager.clearWhere((key) => key.startsWith('transactions_page_'));
      _cacheManager.clear('transaction_details_$transactionId');
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.deleteTransaction');
      throw ServerException('transaction_error_delete_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.deleteTransaction');
      throw ServerException('transaction_error_delete_failed');
    }
  }

  /// Fetches all transactions for a store with explicit pagination.
  /// Phase 4: Made stateless by requiring [lastDocument] parameter.
  Future<PaginatedResult<TransactionModel>> getAllTransactions(String storeId,
      {DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _transactionsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('isDeleted', isEqualTo: false);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(20).get();
      final items = <TransactionModel>[];
      for (final doc in snapshot.docs) {
        try {
          items.add(TransactionModel.fromFirestore(doc));
        } catch (e, stack) {
          AppErrorHandler.logSilentError(
              'Malformed tx doc in all list: ${doc.id} | error: $e',
              'transaction_all_list_corruption',
              stackTrace: stack);
        }
      }

      return PaginatedResult(
        items: items,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.getAllTransactions');
      throw ServerException('transaction_error_fetch_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'TransactionRepository.getAllTransactions');
      throw ServerException('transaction_error_fetch_failed');
    }
  }
}
