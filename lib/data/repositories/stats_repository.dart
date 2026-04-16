import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/core/utils/date_helper.dart';

class StatsRepository {
  final FirebaseFirestore _firestore;

  StatsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference _getSummaryDocRef(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('stats')
        .doc('summary');
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
          .collection('stores')
          .doc(storeId)
          .collection('daily_stats')
          .doc(todayDate);

      final doc = await docRef.get();
      if (doc.exists) {
        return DailyStatsModel.fromMap(
            doc.data() as Map<String, dynamic>, doc.id);
      } else {
        return DailyStatsModel.empty(todayDate);
      }
    } catch (e) {
      return DailyStatsModel.empty(DateHelper.getCurrentDateString());
    }
  }

  Stream<DailyStatsModel> watchTodayStats(String storeId) {
    final todayDate = DateHelper.getCurrentDateString();
    return _firestore
        .collection('stores')
        .doc(storeId)
        .collection('daily_stats')
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
    return _getSummaryDocRef(storeId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return StatsSummaryModel.fromMap(data);
      } else {
        // If it doesn't exist, we'll initialize it and the stream will get the new data.
        initializeStats(storeId);
        return StatsSummaryModel.empty();
      }
    });
  }

  Future<StatsSummaryModel> initializeStats(String storeId) async {
    final summary = StatsSummaryModel.empty();
    await _getSummaryDocRef(storeId).set(summary.toMap());
    return summary;
  }

  Future<void> updateStatsOnTransactionCreate(
      String storeId, TransactionModel tx) async {
    final docRef = _getSummaryDocRef(storeId);
    final Map<String, dynamic> updates = {
      'totalTransactions': FieldValue.increment(1),
      'totalTransactionsToday': FieldValue.increment(1),
      'totalCommission': FieldValue.increment(tx.commission),
      'totalCommissionToday': FieldValue.increment(tx.commission),
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (tx.isSend) {
      updates['sendCount'] = FieldValue.increment(1);
      updates['totalSentAmount'] = FieldValue.increment(tx.amount);
    } else if (tx.isReceive) {
      updates['receiveCount'] = FieldValue.increment(1);
      updates['totalReceivedAmount'] = FieldValue.increment(tx.amount);
    }
    await docRef.update(updates);
  }

  Future<void> incrementOpenDebtStats(String storeId, double amount) async {
    final docRef = _getSummaryDocRef(storeId);
    await docRef.update({
      'openDebtsCount': FieldValue.increment(1),
      'totalOpenAmount': FieldValue.increment(amount),
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateStatsOnDebtUpdate({
    required Transaction firestoreTransaction,
    required String storeId,
    DebtModel? oldDebt, // Null for creation
    required DebtModel newDebt,
  }) async {
    final summaryRef = _getSummaryDocRef(storeId);
    final Map<String, FieldValue> updates = {
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (oldDebt == null) {
      // --- Handle Creation ---
      updates['openDebtsCount'] = FieldValue.increment(1);
      updates['totalOpenAmount'] = FieldValue.increment(newDebt.amountDue);
    } else {
      // --- Handle Update ---
      final wasPaid = oldDebt.debtStatus == 'paid';
      final isNowPaid = newDebt.debtStatus == 'paid';
      final wasOpen = oldDebt.debtStatus == 'open';
      final isNowOpen = newDebt.debtStatus == 'open';

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
        updates['openDebtsCount'] = FieldValue.increment(-1);
        updates['paidDebtsCount'] = FieldValue.increment(1);
      } else if (wasPaid && isNowOpen) {
        // Paid -> Open (Re-opening a paid debt)
        updates['openDebtsCount'] = FieldValue.increment(1);
        updates['paidDebtsCount'] = FieldValue.increment(-1);
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
      double balanceChange = 0.0}) async {
    if (countChange == 0 && activeCountChange == 0 && balanceChange == 0.0) {
      return;
    }

    final docRef = _getSummaryDocRef(storeId);
    final Map<String, dynamic> updates = {
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    if (countChange != 0) {
      updates['totalWallets'] = FieldValue.increment(countChange);
    }
    if (activeCountChange != 0) {
      updates['activeWallets'] = FieldValue.increment(activeCountChange);
    }
    if (balanceChange != 0.0) {
      updates['totalBalance'] = FieldValue.increment(balanceChange);
    }
    await docRef.update(updates);

    // Also update Store Document root stats field (Legacy support)
    final storeRef = _firestore.collection('stores').doc(storeId);
    final Map<String, dynamic> storeUpdates = {
      'stats.lastUpdated': FieldValue.serverTimestamp(),
    };
    if (countChange != 0) {
      storeUpdates['stats.totalWallets'] = FieldValue.increment(countChange);
    }
    if (activeCountChange != 0) {
      storeUpdates['stats.activeWallets'] =
          FieldValue.increment(activeCountChange);
    }
    await storeRef.update(storeUpdates);
  }

  Future<void> reconcileStatsFromWallets(String storeId) async {
    try {
      final snapshots = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('wallets')
          .get();
      double totalBalance = snapshots.docs.fold(
          0, (acc, doc) => acc + (doc.data()['balance'] as num).toDouble());
      int totalWallets = snapshots.docs.length;

      final summaryRef = _getSummaryDocRef(storeId);
      await summaryRef.update({
        'totalWallets': totalWallets,
        'totalBalance': totalBalance,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reconcileStatsFromDebts(String storeId) async {
    try {
      // 1. Get all debt documents for the store
      final debtQuery =
          _firestore.collection('debts').where('storeId', isEqualTo: storeId);
      final debtSnapshot = await debtQuery.get();

      // 2. Compute authoritative values
      int openDebtsCount = 0;
      double totalOpenAmount = 0.0;
      int paidDebtsCount = 0;

      for (final doc in debtSnapshot.docs) {
        final debt = DebtModel.fromFirestore(doc);
        if (debt.debtStatus == 'open') {
          openDebtsCount++;
          totalOpenAmount += debt.amountDue;
        } else if (debt.debtStatus == 'paid') {
          paidDebtsCount++;
        }
      }

      final summaryRef = _getSummaryDocRef(storeId);

      // 4. Atomically write the new values
      final reconciledStats = {
        'openDebtsCount': openDebtsCount,
        'totalOpenAmount': totalOpenAmount,
        'paidDebtsCount': paidDebtsCount,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await summaryRef.update(reconciledStats);
    } catch (e) {
      rethrow;
    }
  }
}
