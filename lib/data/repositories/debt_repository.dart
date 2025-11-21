import 'package:walletmanager/core/utils/cache_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:walletmanager/data/repositories/stats_repository.dart';

import '../../core/constants/firebase_constants.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/debt_model.dart';
import '../services/firebase_service.dart';

class DebtRepository {
  final FirebaseService _firebaseService;
  final CacheManager _cacheManager;
  final StatsRepository _statsRepository;

  DebtRepository({
    FirebaseService? firebaseService,
    CacheManager? cacheManager,
    StatsRepository? statsRepository,
  })  : _firebaseService = firebaseService ?? FirebaseService(),
        _cacheManager = cacheManager ?? CacheManager(),
        _statsRepository = statsRepository ?? StatsRepository();

  FirebaseFirestore get _firestore => _firebaseService.firestore;
  CollectionReference get _debtsCollection =>
      _firestore.collection(FirebaseConstants.debts);

  // 1️⃣ CREATE
  Future<void> createDebt(DebtModel debt) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Perform all reads first
        // The _statsRepository.updateStatsOnDebtUpdate method will perform its own read
        // (transaction.get(summaryRef)) before its write.
        await _statsRepository.updateStatsOnDebtUpdate(
          firestoreTransaction: transaction,
          storeId: debt.storeId,
          oldDebt: null, // Indicates creation
          newDebt: debt,
        );

        // 2. Perform all writes after all reads
        final debtDocRef = _debtsCollection.doc(debt.debtId);
        transaction.set(debtDocRef, debt.toFirestore());
      });
      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
    } on FirebaseException catch (e) {
      throw ServerException('Failed to create debt: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('An unexpected error occurred while creating the debt: $e');
    }
  }

  // 2️⃣ READ
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
      throw ServerException('An unexpected error occurred while fetching the debt.');
    }
  }

  Future<Map<String, dynamic>> getDebtsByStoreIdPaginated(
    String storeId, {
    String? status,
    int limit = 15,
    DocumentSnapshot? lastDoc,
  }) async {
    // Caching logic remains the same
    if (lastDoc == null) {
      final cacheKey = 'debts_page_0_${storeId}_$status';
      final cachedResult = _cacheManager.get<Map<String, dynamic>>(cacheKey);
      if (cachedResult != null) {
        return cachedResult;
      }
    }

    try {
      Query query = _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .orderBy('debtDate', descending: true);

      if (status != null) {
        query = query.where('debtStatus', isEqualTo: status);
      }

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.limit(limit).get();
      final debts = snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
      final newLastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      final result = {
        'debts': debts,
        'lastDoc': newLastDoc,
      };

      if (lastDoc == null) {
        final cacheKey = 'debts_page_0_${storeId}_$status';
        _cacheManager.set(cacheKey, result);
      }

      return result;
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get store debts: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('An unexpected error occurred while fetching store debts.');
    }
  }

  // Other read methods remain the same...
  Future<DebtModel?> getDebtByCustomerName(String storeId, String customerName) async {
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
      throw ServerException('Failed to get debt by customer name: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('An unexpected error occurred while fetching debt by customer name.');
    }
  }

  Future<DebtModel?> getDebtByCustomerPhone(String storeId, String customerPhone) async {
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
      throw ServerException('Failed to get debt by customer phone: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('An unexpected error occurred while fetching debt by customer phone.');
    }
  }

  // 3️⃣ UPDATE
  Future<void> processPayment(String debtId, double amountToPay, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // --- All READ operations must come first ---
        final debtDocRef = _debtsCollection.doc(debtId);
        final debtDoc = await transaction.get(debtDocRef);

        if (!debtDoc.exists) {
          throw NotFoundException('Debt');
        }

        final oldDebt = DebtModel.fromFirestore(debtDoc);

        if (amountToPay <= 0) throw ValidationException('Amount must be positive.');
        if (amountToPay > oldDebt.amountDue) throw ValidationException('Paid amount exceeds remaining debt.');

        final isFullPayment = (oldDebt.amountDue - amountToPay).abs() < 0.01;
        
        final Map<String, dynamic> updateData = {
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        };
        
        DebtModel newDebt;

        if (isFullPayment) {
          updateData['amountDue'] = 0.0;
          updateData['debtStatus'] = 'paid';
          updateData['paidDate'] = FieldValue.serverTimestamp();
          updateData['markedPaidBy'] = userId;
          newDebt = oldDebt.copyWith(
            amountDue: 0.0,
            debtStatus: 'paid',
          );
        } else {
          updateData['amountDue'] = FieldValue.increment(-amountToPay);
          newDebt = oldDebt.copyWith(
            amountDue: oldDebt.amountDue - amountToPay,
          );
        }

        // This method performs its own read and queues its write. It must be called before our write below.
        await _statsRepository.updateStatsOnDebtUpdate(
          firestoreTransaction: transaction,
          storeId: oldDebt.storeId,
          oldDebt: oldDebt,
          newDebt: newDebt,
        );

        // --- All WRITE operations must come last ---
        transaction.update(debtDocRef, updateData);
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to process payment: ${e.message}', code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('An unexpected error occurred while processing the payment: $e');
    }
  }

  Future<void> addPartialDebt(String debtId, double amountToAdd, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // --- All READ operations must come first ---
        final debtDocRef = _debtsCollection.doc(debtId);
        final debtDoc = await transaction.get(debtDocRef);

        if (!debtDoc.exists) {
          throw NotFoundException('Debt');
        }

        final oldDebt = DebtModel.fromFirestore(debtDoc);

        if (amountToAdd <= 0) throw ValidationException('Amount must be positive.');

        final wasPaid = oldDebt.debtStatus == 'paid';

        final Map<String, dynamic> updateData = {
          'amountDue': FieldValue.increment(amountToAdd),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastUpdatedBy': userId,
        };

        // If a paid debt is being reopened, update its status
        if (wasPaid) {
          updateData['debtStatus'] = 'open';
        }

        final newDebt = oldDebt.copyWith(
          amountDue: oldDebt.amountDue + amountToAdd,
          debtStatus: wasPaid ? 'open' : oldDebt.debtStatus,
        );

        // This method performs its own read and queues its write. It must be called before our write below.
        await _statsRepository.updateStatsOnDebtUpdate(
          firestoreTransaction: transaction,
          storeId: oldDebt.storeId,
          oldDebt: oldDebt,
          newDebt: newDebt,
        );

        // --- All WRITE operations must come last ---
        transaction.update(debtDocRef, updateData);
      });

      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to add partial debt: ${e.message}', code: e.code);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException('An unexpected error occurred while adding partial debt: $e');
    }
  }

  Future<void> updateDebt(String debtId, Map<String, dynamic> data) async {
    try {
      await _debtsCollection.doc(debtId).update(data);
      _cacheManager.clearWhere((key) => key.startsWith('debts_page_0_'));
      _cacheManager.clear('debt_details_$debtId');
    } on FirebaseException catch (e) {
      throw ServerException('Failed to update debt: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('An unexpected error occurred while updating the debt.');
    }
  }

  Future<Map<String, dynamic>> getDebtAggregates(String storeId, {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _debtsCollection.where(FirebaseConstants.storeId, isEqualTo: storeId);

      if (startDate != null) {
        query = query.where('debtDate', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('debtDate', isLessThanOrEqualTo: endDate);
      }

      final snapshot = await query.get();

      int openDebtsCount = 0;
      double totalOpenAmount = 0.0;
      int paidDebtsCount = 0;
      double totalPaidAmount = 0.0;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['debtStatus'] == 'open') {
          openDebtsCount++;
          totalOpenAmount += (data['amountDue'] ?? 0.0).toDouble();
        } else if (data['debtStatus'] == 'paid') {
          paidDebtsCount++;
          totalPaidAmount += (data['amountDue'] ?? 0.0).toDouble();
        }
      }

      return {
        'openDebtsCount': openDebtsCount,
        'totalOpenAmount': totalOpenAmount,
        'paidDebtsCount': paidDebtsCount,
        'totalPaidAmount': totalPaidAmount,
        'totalDebtsCount': openDebtsCount + paidDebtsCount,
      };
    } catch (e) {
      return {
        'openDebtsCount': 0,
        'totalOpenAmount': 0.0,
        'paidDebtsCount': 0,
        'totalPaidAmount': 0.0,
        'totalDebtsCount': 0,
      };
    }
  }

  Future<List<DebtModel>> getDebtsByDateRange(String storeId, DateTime startDate, DateTime endDate) async {
    try {
      final snapshot = await _debtsCollection
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .where('createdAt', isGreaterThanOrEqualTo: startDate)
          .where('createdAt', isLessThanOrEqualTo: endDate)
          .get();
      return snapshot.docs.map((doc) => DebtModel.fromFirestore(doc)).toList();
    } on FirebaseException catch (e) {
      throw ServerException('Failed to get debts by date range: ${e.message}', code: e.code);
    } catch (e) {
      throw ServerException('An unexpected error occurred while fetching debts by date range.');
    }
  }

  Future<int> getDebtsCount(String storeId, {String? status}) async {
    try {
      Query query = _debtsCollection.where(FirebaseConstants.storeId, isEqualTo: storeId);
      if (status != null) {
        query = query.where('debtStatus', isEqualTo: status);
      }
      // Use aggregate query for efficiency
      final countQuery = query.count();
      final snapshot = await countQuery.get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<double> getDebtsTotalAmount(String storeId, {String? status}) async {
    try {
      Query query = _debtsCollection.where(FirebaseConstants.storeId, isEqualTo: storeId);
      if (status != null) {
        query = query.where('debtStatus', isEqualTo: status);
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
    // Not implemented for MVP as per instructions.
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
}
