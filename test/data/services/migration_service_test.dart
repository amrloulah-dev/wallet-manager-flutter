import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/services/migration_service.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MigrationService migrationService;

  const storeId = 'test_store';

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    migrationService = MigrationService(firestore: fakeFirestore);
  });

  group('MigrationService - Recalculate Stats (TDD)', () {
    test('recalculateStoreStats should correctly restore stats from collections', () async {
      // ARRANGE: Setup desynchronized state
      
      // 1. Wallets (Actual: 2 wallets, 1 active, 150.0 total balance)
      await fakeFirestore.collection(FirebaseConstants.walletsCollection).add({
        FirebaseConstants.storeId: storeId,
        FirebaseConstants.isActive: true,
        'balance': 100.0,
      });
      await fakeFirestore.collection(FirebaseConstants.walletsCollection).add({
        FirebaseConstants.storeId: storeId,
        FirebaseConstants.isActive: false,
        'balance': 50.0,
      });

      // 2. Debts (Actual: 1 open debt of 200.0)
      await fakeFirestore.collection(FirebaseConstants.debts).add({
        FirebaseConstants.storeId: storeId,
        'debtStatus': DebtStatus.open.name,
        'amountDue': 200.0,
      });

      // 3. Transactions (Actual: 1 send tx of 100.0, 10.0 commission, 5.0 fee)
      await fakeFirestore.collection(FirebaseConstants.transactions).add({
        FirebaseConstants.storeId: storeId,
        'transactionType': TransactionType.debit.name,
        'amount': 100.0,
        'commission': 10.0,
        'serviceFee': 5.0,
        'transactionDate': DateTime.now(),
        'createdAt': DateTime.now(),
      });

      // 4. Broken Stats Summary (Desynced values)
      final summaryRef = fakeFirestore
          .collection(FirebaseConstants.storesCollection)
          .doc(storeId)
          .collection(FirebaseConstants.statsCollection)
          .doc(FirebaseConstants.summaryDoc);
      
      await summaryRef.set({
        'totalWallets': 0,
        'activeWallets': 0,
        'totalBalance': 0.0,
        'openDebtsCount': 0,
        'totalOpenAmount': 0.0,
        'totalTransactions': 0,
        'totalCommission': 0.0,
      });

      // ACT
      await migrationService.recalculateStoreStats(storeId);

      // ASSERT
      final snapshot = await summaryRef.get();
      final data = snapshot.data()!;

      expect(data['totalWallets'], 2);
      expect(data['activeWallets'], 1);
      expect(data['totalBalance'], 100.0); // Only active wallet balance
      expect(data['openDebtsCount'], 1);
      expect(data['totalOpenAmount'], 200.0);
      expect(data['totalTransactions'], 1);
      expect(data['totalCommission'], 10.0);
      expect(data['totalServiceFee'], 5.0);
    });
  });
}
