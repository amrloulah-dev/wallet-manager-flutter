import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:walletmanager/core/utils/amount_validator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/core/utils/number_parser.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/error_severity.dart';
import 'package:walletmanager/core/di/service_locator.dart';

class StatsRepository {
  final FirebaseFirestore _firestore;

  StatsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseFirestore>();

  DocumentReference _getSummaryDocRef(String storeId) {
    return _firestore
        .collection(FirebaseConstants.storesCollection)
        .doc(storeId)
        .collection(FirebaseConstants.statsCollection)
        .doc(FirebaseConstants.summaryDoc);
  }

  Future<StatsSummaryModel> getStatsSummary(String storeId) async {
    final docRef = _getSummaryDocRef(storeId);
    final doc = await docRef.get();
    if (doc.exists) {
      return StatsSummaryModel.fromMap(doc.data() as Map<String, dynamic>);
    } else {
      return initializeStats(storeId);
    }
  }

  Future<DailyStatsModel> fetchTodayStats(String storeId) async {
    try {
      final todayDate = DateHelper.getCurrentDateString();
      final docRef = _firestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection(FirebaseConstants.dailyStatsCollection)
          .doc(todayDate);

      final doc = await docRef.get();
      if (doc.exists) {
        return DailyStatsModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      } else {
        return DailyStatsModel.empty(todayDate);
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        severity: ErrorSeverity.low,
        operation: 'StatsRepository.fetchTodayStats',
      );
      return DailyStatsModel.empty(DateHelper.getCurrentDateString());
    }
  }

  Stream<DailyStatsModel> watchTodayStats(String storeId) {
    final todayDate = DateHelper.getCurrentDateString();
    return _firestore
        .collection(FirebaseConstants.storesCollection)
        .doc(storeId)
        .collection(FirebaseConstants.dailyStatsCollection)
        .doc(todayDate)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return DailyStatsModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      } else {
        return DailyStatsModel.empty(todayDate);
      }
    });
  }

  Stream<StatsSummaryModel> watchStatsSummary(String storeId) {
    return _getSummaryDocRef(storeId).snapshots().asyncMap((doc) async {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return StatsSummaryModel.fromMap(data);
      } else {
        // Phase 4: Properly await initialization to avoid race conditions
        await initializeStats(storeId);
        return StatsSummaryModel.empty();
      }
    });
  }

  Future<StatsSummaryModel> initializeStats(String storeId) async {
    final summary = StatsSummaryModel.empty();
    await _getSummaryDocRef(storeId).set(summary.toMap());
    return summary;
  }

  Future<void> incrementOpenDebtStats(String storeId, double amount) async {
    AmountValidator.ensurePositive(amount);
    final docRef = _getSummaryDocRef(storeId);
    await docRef.update({
      'openDebtsCount': FieldValue.increment(1),
      'totalOpenAmount': FieldValue.increment(amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  @visibleForTesting
  Future<void> updateStatsOnDebtUpdate({
    required Transaction firestoreTransaction,
    required String storeId,
    DebtModel? oldDebt, // Null for creation
    required DebtModel newDebt,
  }) async {
    final summaryRef = _getSummaryDocRef(storeId);

    // --- Read operations first ---
    final summarySnap = await firestoreTransaction.get(summaryRef);
    int currentOpenDebts = 0;
    int currentPaidDebts = 0;

    if (summarySnap.exists) {
      final data = summarySnap.data() as Map<String, dynamic>;
      currentOpenDebts = (data['openDebtsCount'] as int?) ?? 0;
      currentPaidDebts = (data['paidDebtsCount'] as int?) ?? 0;
    }

    final Map<String, dynamic> updates = {
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (oldDebt == null) {
      // --- Handle Creation ---
      updates['openDebtsCount'] = FieldValue.increment(1);
      updates['totalOpenAmount'] = FieldValue.increment(newDebt.amountDue);
    } else {
      // --- Handle Update ---
      final wasPaid = oldDebt.debtStatus == DebtStatus.paid; // ENUM refactor
      final isNowPaid = newDebt.debtStatus == DebtStatus.paid; // ENUM refactor
      final wasOpen = oldDebt.debtStatus == DebtStatus.open; // ENUM refactor
      final isNowOpen = newDebt.debtStatus == DebtStatus.open; // ENUM refactor

      final amountChange = newDebt.amountDue - oldDebt.amountDue;

      // --- Handle Amount Changes ---
      if (amountChange.abs() > 0.001) {
        updates['totalOpenAmount'] = FieldValue.increment(amountChange);

        if (amountChange < 0) {
          // Payment
          updates['totalPaidAmount'] = FieldValue.increment(-amountChange);
        }
      }

      // --- Handle Status Changes ---
      if (wasOpen && isNowPaid) {
        // Open -> Paid (Full Payment)
        updates['openDebtsCount'] = currentOpenDebts > 0 ? currentOpenDebts - 1 : 0;
        updates['paidDebtsCount'] = FieldValue.increment(1);
      } else if (wasPaid && isNowOpen) {
        // Paid -> Open (Re-opening a paid debt)
        updates['openDebtsCount'] = FieldValue.increment(1);
        updates['paidDebtsCount'] = currentPaidDebts > 0 ? currentPaidDebts - 1 : 0;
      }
    }

    if (updates.length > 1) {
      // more than just lastUpdated
      firestoreTransaction.set(summaryRef, updates, SetOptions(merge: true));
    }
  }

  Future<void> updateStatsOnWalletChange(String storeId,
      {int countChange = 0,
      int activeCountChange = 0,
      double balanceChange = 0.0,
      Transaction? firestoreTransaction}) async {
    if (countChange == 0 && activeCountChange == 0 && balanceChange == 0.0) {
      return;
    }

    Future<void> updateLogic(Transaction transaction) async {
      final summaryRef = _getSummaryDocRef(storeId);
      final summarySnap = await transaction.get(summaryRef);

      final Map<String, dynamic> summaryUpdates = {
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      if (countChange != 0) {
        int currentTotal = 0;
        if (summarySnap.exists) {
          final data = summarySnap.data() as Map<String, dynamic>?;
          currentTotal = (data?['totalWallets'] as int?) ?? 0;
        }
        final newTotal = (currentTotal + countChange).clamp(0, 999999).toInt();
        summaryUpdates['totalWallets'] = newTotal;
      }

      if (activeCountChange != 0) {
        int currentActive = 0;
        if (summarySnap.exists) {
          final data = summarySnap.data() as Map<String, dynamic>?;
          currentActive = (data?['activeWallets'] as int?) ?? 0;
        }
        final newActive =
            (currentActive + activeCountChange).clamp(0, 999999).toInt();
        summaryUpdates['activeWallets'] = newActive;
      }

      if (balanceChange != 0.0) {
        double currentBalance = 0.0;
        if (summarySnap.exists) {
          final data = summarySnap.data() as Map<String, dynamic>?;
          currentBalance = NumberParser.toDouble(data?['totalBalance']);
        }
        summaryUpdates['totalBalance'] = currentBalance + balanceChange;
      }

      transaction.set(summaryRef, summaryUpdates, SetOptions(merge: true));
    }

    if (firestoreTransaction != null) {
      await updateLogic(firestoreTransaction);
    } else {
      await _firestore.runTransaction((transaction) async {
        await updateLogic(transaction);
      });
    }
  }
}
