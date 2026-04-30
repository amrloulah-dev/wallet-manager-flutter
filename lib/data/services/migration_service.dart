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
    final walletsSnapshot = await _firestore
        .collection(FirebaseConstants.walletsCollection)
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .get();

    int totalWallets = 0;
    int activeWallets = 0;
    double totalBalance = 0.0;

    for (var doc in walletsSnapshot.docs) {
      final data = doc.data();
      final bool isActive = data[FirebaseConstants.isActive] as bool? ?? false;
      final double balance = NumberParser.toDouble(data['balance']);

      totalWallets++;
      if (isActive) {
        activeWallets++;
        totalBalance += balance;
      }
    }

    // 2. Recalculate Debts
    final debtsSnapshot = await _firestore
        .collection(FirebaseConstants.debts)
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .get();

    int openDebtsCount = 0;
    int paidDebtsCount = 0;
    double totalOpenAmount = 0.0;
    double totalPaidAmount = 0.0;

    for (var doc in debtsSnapshot.docs) {
      final data = doc.data();
      final statusStr = data['debtStatus'] as String? ?? 'open';
      final status = DebtStatus.fromString(statusStr);
      final double amountDue = NumberParser.toDouble(data['amountDue']);
      final double amountPaid = NumberParser.toDouble(data['amountPaid']);

      if (status == DebtStatus.open) {
        openDebtsCount++;
        totalOpenAmount += amountDue;
      } else if (status == DebtStatus.paid) {
        paidDebtsCount++;
        totalPaidAmount += amountPaid;
      }
    }

    // 3. Recalculate Transactions
    final transactionsSnapshot = await _firestore
        .collection(FirebaseConstants.transactions)
        .where(FirebaseConstants.storeId, isEqualTo: storeId)
        .get();

    int totalTransactions = 0;
    int sendCount = 0;
    int receiveCount = 0;
    double totalSentAmount = 0.0;
    double totalReceivedAmount = 0.0;
    double totalCommission = 0.0;
    double totalServiceFee = 0.0;

    for (var doc in transactionsSnapshot.docs) {
      final data = doc.data();
      final typeStr = data['transactionType'] as String? ?? 'send';
      final type = TransactionType.fromString(typeStr);
      final double amount = NumberParser.toDouble(data['amount']);
      final double commission = NumberParser.toDouble(data['commission']);
      final double serviceFee = NumberParser.toDouble(data['serviceFee']);

      totalTransactions++;
      totalCommission += commission;
      totalServiceFee += serviceFee;

      if (type == TransactionType.debit) {
        sendCount++;
        totalSentAmount += amount;
      } else if (type == TransactionType.credit) {
        receiveCount++;
        totalReceivedAmount += amount;
      }
    }

    // 4. Update Stats Summary
    final summaryRef = _firestore
        .collection(FirebaseConstants.storesCollection)
        .doc(storeId)
        .collection(FirebaseConstants.statsCollection)
        .doc(FirebaseConstants.summaryDoc);

    await summaryRef.set({
      'totalWallets': totalWallets,
      'activeWallets': activeWallets,
      'totalBalance': totalBalance,
      'openDebtsCount': openDebtsCount,
      'paidDebtsCount': paidDebtsCount,
      'totalOpenAmount': totalOpenAmount,
      'totalPaidAmount': totalPaidAmount,
      'totalTransactions': totalTransactions,
      'sendCount': sendCount,
      'receiveCount': receiveCount,
      'totalSentAmount': totalSentAmount,
      'totalReceivedAmount': totalReceivedAmount,
      'totalCommission': totalCommission,
      'totalServiceFee': totalServiceFee,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
