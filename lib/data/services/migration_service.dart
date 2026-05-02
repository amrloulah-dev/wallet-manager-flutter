import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/enums/transaction_enums.dart';
import '../../core/enums/debt_enums.dart';
import '../../core/utils/number_parser.dart';
import '../../core/di/service_locator.dart';

class MigrationService {
  final FirebaseFirestore _firestore;

  MigrationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseFirestore>();

  Future<void> recalculateStoreStats(String storeId) async {
    // 1. Recalculate Wallets
    final walletsBaseQuery = _firestore
        .collection(FirebaseConstants.walletsCollection)
        .where(FirebaseConstants.storeId, isEqualTo: storeId);
    
    final walletsTotalCount = await walletsBaseQuery.count().get();
    
    final activeWalletsQuery = walletsBaseQuery.where(FirebaseConstants.isActive, isEqualTo: true);
    final activeWalletsStats = await activeWalletsQuery.aggregate(
      count(),
      sum('balance'),
    ).get();

    // 2. Recalculate Debts
    final debtsBaseQuery = _firestore
        .collection(FirebaseConstants.debts)
        .where(FirebaseConstants.storeId, isEqualTo: storeId);
    
    final openDebtsQuery = debtsBaseQuery.where('debtStatus', isEqualTo: DebtStatus.open.name);
    final openDebtsStats = await openDebtsQuery.aggregate(
      count(),
      sum('amountDue'),
    ).get();

    final paidDebtsQuery = debtsBaseQuery.where('debtStatus', isEqualTo: DebtStatus.paid.name);
    final paidDebtsStats = await paidDebtsQuery.aggregate(
      count(),
      sum('amountPaid'),
    ).get();

    // 3. Recalculate Transactions
    final transactionsBaseQuery = _firestore
        .collection(FirebaseConstants.transactions)
        .where(FirebaseConstants.storeId, isEqualTo: storeId);
    
    final transactionsStats = await transactionsBaseQuery.aggregate(
      count(),
      sum('commission'),
      sum('serviceFee'),
    ).get();

    final sendTransactionsQuery = transactionsBaseQuery.where('transactionType', isEqualTo: TransactionType.debit.name);
    final sendStats = await sendTransactionsQuery.aggregate(
      count(),
      sum('amount'),
    ).get();

    final receiveTransactionsQuery = transactionsBaseQuery.where('transactionType', isEqualTo: TransactionType.credit.name);
    final receiveStats = await receiveTransactionsQuery.aggregate(
      count(),
      sum('amount'),
    ).get();

    // 4. Update Stats Summary
    final summaryRef = _firestore
        .collection(FirebaseConstants.storesCollection)
        .doc(storeId)
        .collection(FirebaseConstants.statsCollection)
        .doc(FirebaseConstants.summaryDoc);

    await summaryRef.set({
      'totalWallets': walletsTotalCount.count ?? 0,
      'activeWallets': activeWalletsStats.count ?? 0,
      'totalBalance': activeWalletsStats.getSum('balance') ?? 0.0,
      'openDebtsCount': openDebtsStats.count ?? 0,
      'paidDebtsCount': paidDebtsStats.count ?? 0,
      'totalOpenAmount': openDebtsStats.getSum('amountDue') ?? 0.0,
      'totalPaidAmount': paidDebtsStats.getSum('amountPaid') ?? 0.0,
      'totalTransactions': transactionsStats.count ?? 0,
      'sendCount': sendStats.count ?? 0,
      'receiveCount': receiveStats.count ?? 0,
      'totalSentAmount': sendStats.getSum('amount') ?? 0.0,
      'totalReceivedAmount': receiveStats.getSum('amount') ?? 0.0,
      'totalCommission': transactionsStats.getSum('commission') ?? 0.0,
      'totalServiceFee': transactionsStats.getSum('serviceFee') ?? 0.0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
