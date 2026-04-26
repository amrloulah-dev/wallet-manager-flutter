import 'package:walletmanager/core/utils/amount_validator.dart';
import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/debt_model.dart';
import '../services/firebase_service.dart';

class DebtRepository {
  final FirebaseService _firebaseService;
  final CacheManager _cacheManager;

  DebtRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _cacheManager = cacheManager ?? CacheManager();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  CollectionReference get _debtsCollection =>
      _firestore.collection(FirebaseConstants.debts);

  String generateId() => _debtsCollection.doc().id;

  DocumentSnapshot? _lastDocument;

  void resetPagination() {
    _lastDocument = null;
  }

  // 1️⃣ CREATE
  Future<void> createDebt(DebtModel debt) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final statsRef = _firestore
            .collection('stores')
            .doc(debt.storeId)
            .collection('stats')
            .doc('summary');

        final Map<String, dynamic> statsUpdates = {
          'lastUpdated': FieldValue.serverTimestamp(),
          'openDebtsCount': FieldValue.increment(1),
          'totalOpenAmount': FieldValue.increment(debt.amountDue),
        };

        // 2. Perform all writes after all reads
        final debtDocRef = _debtsCollection.doc(debt.debtId);
        transaction.set(debtDocRef, debt.toFirestore());
        transaction.set(statsRef, statsUpdates, SetOptions(merge: true));
      });
      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create debt: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while creating the debt: $e');
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
        return snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
      });
    } catch (e) {
      return Stream.error(ServerException('فشل الحصول على تيار الديون: $e'));
    }
  }

  Future<DebtModel?> getDebtById(String debtId) async {
    final cacheKey = 'debt_details_$debtId';
    final cachedDebt = _cacheManager.get<DebtModel>(cacheKey);
    if (cachedDebt != null) {
      return cachedDebt;
    }

    try {
      final doc = await _debtsCollection.doc(debtId).get();
      if (!doc.exists) return null;

      final debt = DebtModel.fromFirestore(doc);
      _cacheManager.set(cacheKey, debt, duration: const Duration(minutes: 10));
      return debt;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get debt: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching the debt.');
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
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get debt by customer name: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching debt by customer name.');
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
    } on FirebaseException catch (e) {
      throw ServerException(
          'Failed to get debt by customer phone: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching debt by customer phone.');
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
          throw ValidationException('Paid amount exceeds remaining debt.');
        }

        final isFullPayment = (oldDebt.amountDue - amountToPay).abs() < 0.01;

        final Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        };

        final statsRef = _firestore
            .collection('stores')
            .doc(oldDebt.storeId)
            .collection('stats')
            .doc('summary');

        final Map<String, dynamic> statsUpdates = {
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (isFullPayment) {
          updateData['amountDue'] = 0.0;
          updateData['debtStatus'] = 'paid';
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
        transaction.set(statsRef, statsUpdates, SetOptions(merge: true));
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to process payment: ${e.message}',
          code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
          'An unexpected error occurred while processing the payment: $e');
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

        final wasPaid = oldDebt.debtStatus == 'paid';

        final Map<String, dynamic> updateData = {
          'amountDue': FieldValue.increment(amountToAdd),
          'totalAmount': FieldValue.increment(amountToAdd), // Increase total
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        };

        final statsRef = _firestore
            .collection('stores')
            .doc(oldDebt.storeId)
            .collection('stats')
            .doc('summary');

        final Map<String, dynamic> statsUpdates = {
          'lastUpdated': FieldValue.serverTimestamp(),
          'totalOpenAmount': FieldValue.increment(amountToAdd),
        };

        if (wasPaid) {
          updateData['debtStatus'] = 'open';
          statsUpdates['openDebtsCount'] = FieldValue.increment(1);
          statsUpdates['paidDebtsCount'] = FieldValue.increment(-1);
          statsUpdates['totalPaidAmount'] =
              FieldValue.increment(-oldDebt.totalAmount);
        }

        // --- All WRITE operations must come last ---
        transaction.update(debtDocRef, updateData);
        transaction.set(statsRef, statsUpdates, SetOptions(merge: true));
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to add partial debt: ${e.message}',
          code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
          'An unexpected error occurred while adding partial debt: $e');
    }
  }

  Future<void> updateDebt(String debtId, Map<String, dynamic> data) async {
    try {
      await _debtsCollection.doc(debtId).update(data);
      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update debt: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while updating the debt.');
    }
  }

  Future<List<DebtModel>> getDebtsByDateRange(
      String storeId, DateTime startDate, DateTime endDate, {bool loadMore = false}) async {
    try {
      Query query = _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .orderBy('createdAt', descending: true);

      if (!loadMore) {
        _lastDocument = null;
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(20).get();
      final items = snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      return items;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get debts by date range: ${e.message}',
          code: e.code);
    } catch (e) {
      throw ServerException(
          'An unexpected error occurred while fetching debts by date range.');
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
    } catch (e) {
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
    } catch (e) {
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
            .collection('stores')
            .doc(storeId)
            .collection('stats')
            .doc('summary');

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
        // Attempt to update stats, assuming the summary document exists.
        // If it doesn't, this part of the transaction will fail, ensuring consistency.
        transaction.update(statsRef, updates);
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to delete debt: ${e.message}',
          code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(
          'An unexpected error occurred while deleting the debt: $e');
    }
  }

  // 5️⃣ STREAM
  Stream<DebtModel> watchDebt(String debtId) {
    return _debtsCollection.doc(debtId).snapshots().map((doc) {
      if (!doc.exists) {
        throw NotFoundException('Debt');
      }
      return DebtModel.fromFirestore(doc);
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
      final openQuery = baseQuery.where('debtStatus', isEqualTo: 'open');
      final openAggregate = openQuery.aggregate(
        sum('amountDue'),
        count(),
      );

      // Paid Debts Query
      final paidQuery = baseQuery.where('debtStatus', isEqualTo: 'paid');

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
    } catch (e) {
      return {
        'openCount': 0,
        'openTotal': 0.0,
        'paidCount': 0,
        'paidTotal': 0.0,
      };
    }
  }
}
