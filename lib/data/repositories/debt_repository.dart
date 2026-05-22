import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:walletmanager/core/utils/amount_validator.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/debt_model.dart';
import '../models/paginated_result.dart';
import '../services/firebase_service.dart';

class DebtRepository {
  final FirebaseService _firebaseService;
  final CacheManager _cacheManager;

  final FirebaseFirestore? _customFirestore;

  DebtRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
    FirebaseFirestore? firestore,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _cacheManager = cacheManager ?? CacheManager(),
        _customFirestore = firestore;

  FirebaseFirestore get _firestore => _customFirestore ?? _firebaseService.firestore;
  CollectionReference get _debtsCollection =>
      _firestore.collection(FirebaseConstants.debts);

  String generateId() => _debtsCollection.doc().id;

  // 1️⃣ CREATE
  Future<void> createDebt(DebtModel debt) async {
    // Pre-validation
    AmountValidator.ensurePositive(debt.amountDue);

    try {
      final batch = _firestore.batch();
      final statsRef =
          _firestore.doc(FirebaseConstants.statsSummaryPath(debt.storeId));

      final Map<String, dynamic> statsUpdates = {
        'lastUpdated': FieldValue.serverTimestamp(),
        'openDebtsCount': FieldValue.increment(1),
        'totalOpenAmount': FieldValue.increment(debt.amountDue),
      };

      final debtDocRef = _debtsCollection.doc(debt.debtId);
      batch.set(debtDocRef, debt.toFirestore());
      batch.set(statsRef, statsUpdates, SetOptions(merge: true));

      await batch.commit();

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_'));
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.createDebt');
      throw ServerException('debt_error_create_failed');
    }
  }

  // 2️⃣ READ
  Stream<List<DebtModel>> getDebtsStream(
    String storeId, {
    String? status,
    String? type,
    int limit = 20,
  }) {
    try {
      Query query = _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .orderBy('debtDate', descending: true);

      if (status != null) {
        query = query.where('debtStatus', isEqualTo: status);
      }

      if (type != null) {
        query = query.where('debtType', isEqualTo: type);
      }

      return query.limit(limit).snapshots().map((snapshot) {
        final List<DebtModel> debts = [];
        for (final doc in snapshot.docs) {
          try {
            debts.add(DebtModel.fromFirestore(doc));
          } catch (e, stackTrace) {
            AppErrorHandler.logSilentError(
              'Skipping corrupt Debt document ${doc.id}: $e',
              'DebtRepository.getDebtsStream',
              stackTrace: stackTrace,
            );
          }
        }
        return debts;
      });
    } catch (e, stack) {
      AppErrorHandler.logSilentError(e.toString(), 'DebtRepository.getDebtsStream',
          stackTrace: stack);
      return Stream.error(ServerException('debt_error_stream_failed'));
    }
  }

  Future<DebtModel?> getDebtById(String debtId, {String? expectedStoreId}) async {
    final cacheKey = 'debt_details_$debtId';
    final cachedDebt = _cacheManager.get<DebtModel>(cacheKey);

    if (cachedDebt != null) {
      if (expectedStoreId != null && cachedDebt.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }
      return cachedDebt;
    }

    try {
      final doc = await _debtsCollection.doc(debtId).get();
      if (!doc.exists) return null;

      final debt = DebtModel.fromFirestore(doc);

      // Post-fetch Tenant Isolation Guard (Report 2: M-5)
      if (expectedStoreId != null && debt.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }

      _cacheManager.set(cacheKey, debt, duration: const Duration(minutes: 10));
      return debt;
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtById');
      throw ServerException('debt_error_fetch_failed', code: e.code);
    } catch (e, stack) {
      if (e is AppException) rethrow;
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtById');
      throw ServerException('debt_error_fetch_failed');
    }
  }

  Future<DebtModel?> getDebtByCustomerName(
      String storeId, String customerName) async {
    try {
      final normalizedName = customerName.trim().toLowerCase();
      final snapshot = await _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('customerNameNormalized', isEqualTo: normalizedName)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return DebtModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtByCustomerName');
      throw ServerException('debt_error_fetch_failed',
          code: e.code);
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtByCustomerName');
      throw ServerException('debt_error_fetch_failed');
    }
  }

  Future<DebtModel?> getDebtByCustomerPhone(
      String storeId, String customerPhone) async {
    try {
      final snapshot = await _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('customerPhone', isEqualTo: customerPhone)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return DebtModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtByCustomerPhone');
      throw ServerException('debt_error_fetch_failed',
          code: e.code);
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtByCustomerPhone');
      throw ServerException('debt_error_fetch_failed');
    }
  }

  // 3️⃣ UPDATE
  Future<void> processPayment(
      String debtId, double amountToPay, String userId) async {
    AmountValidator.ensurePositive(amountToPay);
    try {
      await _firestore.runTransaction((transaction) async {
        // --- All READ operations must come first ---
        final debtDocRef = _debtsCollection.doc(debtId);
        final debtDoc = await transaction.get(debtDocRef);

        if (!debtDoc.exists) {
          throw NotFoundException('Debt');
        }

        final oldDebt = DebtModel.fromFirestore(debtDoc);

        if (amountToPay > oldDebt.amountDue) {
          throw InvalidAmountException('debt_error_amount_exceeded');
        }

        final isFullPayment = (oldDebt.amountDue - amountToPay).abs() < 0.01;

        final Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        };

        final statsRef =
            _firestore.doc(FirebaseConstants.statsSummaryPath(oldDebt.storeId));

        await transaction.get(statsRef);

        final Map<String, dynamic> statsUpdates = {
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (isFullPayment) {
          updateData['amountDue'] = 0.0;
          updateData['debtStatus'] = DebtStatus.paid.name;
          updateData['paidDate'] = FieldValue.serverTimestamp();
          updateData['markedPaidBy'] = userId;

          statsUpdates['openDebtsCount'] = FieldValue.increment(-1);
          statsUpdates['totalOpenAmount'] =
              FieldValue.increment(-oldDebt.amountDue);
          statsUpdates['paidDebtsCount'] = FieldValue.increment(1);
          statsUpdates['totalPaidAmount'] =
              FieldValue.increment(oldDebt.totalAmount);
        } else {
          updateData['amountDue'] = FieldValue.increment(-amountToPay);

          statsUpdates['totalOpenAmount'] = FieldValue.increment(-amountToPay);
        }

        // --- All WRITE operations must come last ---
        transaction.update(debtDocRef, updateData);
        transaction.update(statsRef, statsUpdates);
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.processPayment');
      throw ServerException('debt_error_payment_failed',
          code: e.code);
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.processPayment');
      if (e is AppException) rethrow;
      throw ServerException('debt_error_payment_failed');
    }
  }

  Future<void> addPartialDebt(
      String debtId, double amountToAdd, String userId) async {
    AmountValidator.ensurePositive(amountToAdd);
    try {
      await _firestore.runTransaction((transaction) async {
        // --- All READ operations must come first ---
        final debtDocRef = _debtsCollection.doc(debtId);
        final debtDoc = await transaction.get(debtDocRef);

        if (!debtDoc.exists) {
          throw NotFoundException('Debt');
        }

        final oldDebt = DebtModel.fromFirestore(debtDoc);

        final wasPaid = oldDebt.debtStatus == DebtStatus.paid;

        final Map<String, dynamic> updateData = {
          'amountDue': FieldValue.increment(amountToAdd),
          'totalAmount': FieldValue.increment(amountToAdd), // Increase total
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        };

        final statsRef =
            _firestore.doc(FirebaseConstants.statsSummaryPath(oldDebt.storeId));

        await transaction.get(statsRef);

        final Map<String, dynamic> statsUpdates = {
          'lastUpdated': FieldValue.serverTimestamp(),
          'totalOpenAmount': FieldValue.increment(amountToAdd),
        };

        if (wasPaid) {
          updateData['debtStatus'] = DebtStatus.open.name;
          statsUpdates['openDebtsCount'] = FieldValue.increment(1);
          statsUpdates['paidDebtsCount'] = FieldValue.increment(-1);
          statsUpdates['totalPaidAmount'] =
              FieldValue.increment(-oldDebt.totalAmount);
        }

        // --- All WRITE operations must come last ---
        transaction.update(debtDocRef, updateData);
        transaction.update(statsRef, statsUpdates);
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.addPartialDebt');
      throw ServerException('debt_error_partial_add_failed',
          code: e.code);
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.addPartialDebt');
      if (e is AppException) rethrow;
      throw ServerException('debt_error_partial_add_failed');
    }
  }

  Future<void> updateDebt(String debtId, Map<String, dynamic> data) async {
    // Domain Integrity Guard (Report 2: M-6)
    assert(!data.containsKey(FirebaseConstants.storeId),
        'storeId mutation is strictly forbidden for security reasons.');

    try {
      await _debtsCollection.doc(debtId).update(data);
      _cacheManager.clearWhere((key) => key.startsWith('debts_page_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.updateDebt');
      throw ServerException('debt_error_update_failed',
          code: e.code);
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.updateDebt');
      throw ServerException('debt_error_update_failed');
    }
  }

  Future<PaginatedResult<DebtModel>> getDebtsByDateRange(
      String storeId, DateTime startDate, DateTime endDate,
      {DocumentSnapshot? lastDocument}) async {
    try {
      Query query = _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .orderBy('createdAt', descending: true);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.limit(20).get();
      final List<DebtModel> items = [];
      for (final doc in snapshot.docs) {
        try {
          items.add(DebtModel.fromFirestore(doc));
        } catch (e, stackTrace) {
          AppErrorHandler.logSilentError(
            'Skipping corrupt Debt document ${doc.id}: $e',
            'DebtRepository.getDebtsByDateRange',
            stackTrace: stackTrace,
          );
        }
      }

      return PaginatedResult(
        items: items,
        lastDocument: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      );
    } on FirebaseException catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtsByDateRange');
      throw ServerException('debt_error_fetch_failed',
          code: e.code);
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtsByDateRange');
      throw ServerException('debt_error_fetch_failed');
    }
  }

  Future<int> getDebtsCount(String storeId,
      {String? status, String? type}) async {
    try {
      Query query =
          _debtsCollection.where(FirebaseConstants.storeId, isEqualTo: storeId);
      if (status != null) {
        query = query.where('debtStatus', isEqualTo: status);
      }
      if (type != null) {
        query = query.where('debtType', isEqualTo: type);
      }
      // Use aggregate query for efficiency
      final countQuery = query.count();
      final snapshot = await countQuery.get();
      return snapshot.count ?? 0;
    } catch (e, stack) {
      await AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtsCount');
      return 0;
    }
  }

  Future<double> getDebtsTotalAmount(String storeId,
      {String? status, String? type}) async {
    try {
      Query query =
          _debtsCollection.where(FirebaseConstants.storeId, isEqualTo: storeId);
      if (status != null) {
        query = query.where('debtStatus', isEqualTo: status);
      }
      if (type != null) {
        query = query.where('debtType', isEqualTo: type);
      }

      final aggregateQuery = query.aggregate(sum('amountDue'));
      final snapshot = await aggregateQuery.get();

      return snapshot.getSum('amountDue') ?? 0.0;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.getDebtsTotalAmount');
      return 0.0;
    }
  }

  // 4️⃣ DELETE
  Future<void> deleteDebt(String debtId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final debtDocRef = _debtsCollection.doc(debtId);
        final debtDoc = await transaction.get(debtDocRef);

        if (!debtDoc.exists) {
          throw NotFoundException('Debt');
        }

        final debt = DebtModel.fromFirestore(debtDoc);
        final storeId = debt.storeId;

        // Stats Reference
        final statsRef = _firestore
            .collection(FirebaseConstants.storesCollection)
            .doc(storeId)
            .collection(FirebaseConstants.statsCollection)
            .doc(FirebaseConstants.summaryDoc);

        await transaction.get(statsRef);

        // Prepare Stats Updates
        final Map<String, dynamic> updates = {
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (debt.isOpen) {
          updates['openDebtsCount'] = FieldValue.increment(-1);
          updates['totalOpenAmount'] = FieldValue.increment(-debt.amountDue);
        } else if (debt.isPaid) {
          updates['paidDebtsCount'] = FieldValue.increment(-1);
          updates['totalPaidAmount'] = FieldValue.increment(-debt.totalAmount);
        }

        // Perform Writes
        transaction.delete(debtDocRef);
        transaction.update(statsRef, updates);
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.deleteDebt');
      throw ServerException('debt_error_delete_failed',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.deleteDebt');
      if (e is AppException) rethrow;
      throw ServerException('debt_error_delete_failed');
    }
  }

  // 5️⃣ STREAM
  Stream<DebtModel> watchDebt(String debtId, {String? expectedStoreId}) {
    return _debtsCollection.doc(debtId).snapshots().map((doc) {
      if (!doc.exists) {
        throw NotFoundException('Debt');
      }
      final debt = DebtModel.fromFirestore(doc);

      // Post-fetch Tenant Isolation Guard (Report 2: M-5)
      if (expectedStoreId != null && debt.storeId != expectedStoreId) {
        throw PermissionDeniedException();
      }

      return debt;
    }).handleError((error, stack) {
      AppErrorHandler.logSilentError(error.toString(), 'DebtRepository.watchDebt',
          stackTrace: stack);
      if (error is AppException) throw error;
      throw error;
    });
  }

  // 6️⃣ STATISTICS
  Future<Map<String, dynamic>> fetchDebtStatistics({
    required String storeId,
    required String type,
  }) async {
    try {
      final baseQuery = _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('debtType', isEqualTo: type);

      // Open Debts Query
      final openQuery =
          baseQuery.where('debtStatus', isEqualTo: DebtStatus.open.name);
      final openAggregate = openQuery.aggregate(
        sum('amountDue'),
        count(),
      );

      // Paid Debts Query
      final paidQuery =
          baseQuery.where('debtStatus', isEqualTo: DebtStatus.paid.name);

      // We sum 'totalAmount' (original total)
      final paidAggregate = paidQuery.aggregate(
        sum('totalAmount'),
        count(),
      );

      final results =
          await Future.wait([openAggregate.get(), paidAggregate.get()]);
      final openSnapshot = results[0];
      final paidSnapshot = results[1];

      return {
        'openCount': openSnapshot.count ?? 0,
        'openTotal': openSnapshot.getSum('amountDue') ?? 0.0,
        'paidCount': paidSnapshot.count ?? 0,
        'paidTotal': paidSnapshot.getSum('totalAmount') ?? 0.0,
      };
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DebtRepository.fetchDebtStatistics');
      return {
        'openCount': 0,
        'openTotal': 0.0,
        'paidCount': 0,
        'paidTotal': 0.0,
      };
    }
  }
}
