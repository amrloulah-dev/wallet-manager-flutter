import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/services/transaction_validator_service.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/utils/date_helper.dart';

void main() {
  late TransactionValidatorService service;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    fakeFirestore = FakeFirebaseFirestore();
    service = TransactionValidatorService(firestore: fakeFirestore);
  });

  group('TransactionValidatorService (Atomic Increment Verification)', () {
    test(
        'wallet balance should increment atomically using FieldValue.increment',
        () async {
      // Setup initial state
      final walletId = 'w1';
      final storeId = 's1';
      final initialBalance = 500.0;

      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': initialBalance,
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 5000.0,
          'monthlyUsed': 0.0
        },
        'receiveLimits': {
          'dailyLimit': 1000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 5000.0,
          'monthlyUsed': 0.0
        },
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'stats': {
          'totalTransactions': 0,
        }
      });

      final txModel = TransactionModel(
        transactionId: 'tx1',
        walletId: walletId,
        transactionType: TransactionType.credit, // Receive (Atomic increment)
        amount: 100.0,
        commission: 5.0,
        serviceFee: 0.0,
        storeId: storeId,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '012',
        paymentStatus: PaymentStatus.paid,
      );

      // Execute
      await service.validateAndSave(
          txModel, const PlatformSettingsModel.defaults());

      // Verify final state
      final walletSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .get();
      final finalBalance = walletSnap.data()?['balance'];

      // Note: TransactionValidatorService (Phase 1.4) for Receive uses amount only.
      // Expected: 500.0 + 100.0 = 600.0
      expect(finalBalance, initialBalance + 100.0);
    });

    test('isSend should decrement balance atomically', () async {
      // Setup initial state
      final walletId = 'w2';
      final storeId = 's1';
      final initialBalance = 1000.0;

      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': initialBalance,
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {
          'dailyLimit': 2000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0
        },
        'receiveLimits': {
          'dailyLimit': 2000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0
        },
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'stats': {
          'totalTransactions': 0,
        }
      });

      final txModel = TransactionModel(
        transactionId: 'tx2',
        walletId: walletId,
        transactionType: TransactionType.debit, // Send
        amount: 300.0,
        commission: 10.0,
        serviceFee: 5.0, // Total deduction = 300 + 5 = 305
        storeId: storeId,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '012',
        paymentStatus: PaymentStatus.paid,
      );

      // Execute
      await service.validateAndSave(
          txModel, const PlatformSettingsModel.defaults());

      // Verify final state
      final walletSnap = await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .get();
      final finalBalance = walletSnap.data()?['balance'];

      // Expected: 1000.0 - 305.0 = 695.0
      expect(finalBalance, initialBalance - 305.0);
    });

    test('should increment send/receive counts and amounts in daily stats',
        () async {
      final walletId = 'w3';
      final storeId = 's1';
      final initialBalance = 1000.0;

      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': initialBalance,
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {
          'dailyLimit': 2000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0
        },
        'receiveLimits': {
          'dailyLimit': 2000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 10000.0,
          'monthlyUsed': 0.0
        },
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'stats': {
          'totalTransactions': 0,
        }
      });

      final txModel = TransactionModel(
        transactionId: 'tx3',
        walletId: walletId,
        transactionType: TransactionType.debit, // Send
        amount: 300.0,
        commission: 10.0,
        serviceFee: 5.0,
        storeId: storeId,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '012',
        paymentStatus: PaymentStatus.paid,
      );

      await service.validateAndSave(
          txModel, const PlatformSettingsModel.defaults());

      final todayDate = DateHelper.getCurrentDateString();
      final dailyStatsSnap = await fakeFirestore
          .doc(FirebaseConstants.dailyStatsPath(storeId, todayDate))
          .get();

      expect(dailyStatsSnap.exists, isTrue);
      final data = dailyStatsSnap.data();
      expect(data?['sendCount'], 1);
      expect(data?['totalSentAmount'], 300.0);
    });

    test(
        'validateAndSave updates totalBalance in stores/{storeId}/stats/summary for Send, Receive, and Deposit',
        () async {
      final storeId = 's_stats_test';
      final walletId = 'w_stats_test';
      final initialBalance = 1000.0;
      final initialTotalBalance = 2500.0;

      // Seed stats/summary
      await fakeFirestore
          .doc(FirebaseConstants.statsSummaryPath(storeId))
          .set({
        FirebaseConstants.totalBalance: initialTotalBalance,
        'totalWallets': 2,
        'activeWallets': 2,
      });

      // Seed wallet
      await fakeFirestore
          .collection(FirebaseConstants.walletsCollection)
          .doc(walletId)
          .set({
        'walletId': walletId,
        'storeId': storeId,
        'balance': initialBalance,
        'isActive': true,
        'walletType': 'vodafoneCash',
        'sendLimits': {
          'dailyLimit': 5000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 20000.0,
          'monthlyUsed': 0.0
        },
        'receiveLimits': {
          'dailyLimit': 5000.0,
          'dailyUsed': 0.0,
          'monthlyLimit': 20000.0,
          'monthlyUsed': 0.0
        },
        'createdAt': Timestamp.now(),
        'lastDailyReset': Timestamp.now(),
        'lastMonthlyReset': Timestamp.now(),
        'stats': {'totalTransactions': 0}
      });

      // 1. Test Send (Debit): deduction = amount (200) + serviceFee (10) = 210
      final sendTx = TransactionModel(
        transactionId: 'tx_send_1',
        walletId: walletId,
        transactionType: TransactionType.debit,
        amount: 200.0,
        commission: 5.0,
        serviceFee: 10.0,
        storeId: storeId,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '010',
        paymentStatus: PaymentStatus.paid,
      );

      await service.validateAndSave(
          sendTx, const PlatformSettingsModel.defaults());

      var summarySnap = await fakeFirestore
          .doc(FirebaseConstants.statsSummaryPath(storeId))
          .get();
      // Expected totalBalance: 2500.0 - 210.0 = 2290.0
      expect(summarySnap.data()?[FirebaseConstants.totalBalance], 2290.0);

      // 2. Test Receive (Credit): addition = amount (300)
      final receiveTx = TransactionModel(
        transactionId: 'tx_recv_1',
        walletId: walletId,
        transactionType: TransactionType.credit,
        amount: 300.0,
        commission: 15.0,
        serviceFee: 0.0,
        storeId: storeId,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '010',
        paymentStatus: PaymentStatus.paid,
      );

      await service.validateAndSave(
          receiveTx, const PlatformSettingsModel.defaults());

      summarySnap = await fakeFirestore
          .doc(FirebaseConstants.statsSummaryPath(storeId))
          .get();
      // Expected totalBalance: 2290.0 + 300.0 = 2590.0
      expect(summarySnap.data()?[FirebaseConstants.totalBalance], 2590.0);

      // 3. Test Deposit: addition = amount (500)
      final depositTx = TransactionModel(
        transactionId: 'tx_dep_1',
        walletId: walletId,
        transactionType: TransactionType.deposit,
        amount: 500.0,
        commission: 0.0,
        serviceFee: 0.0,
        storeId: storeId,
        createdBy: 'u1',
        createdAt: DateTime.now(),
        customerPhone: '010',
        paymentStatus: PaymentStatus.paid,
      );

      await service.validateAndSave(
          depositTx, const PlatformSettingsModel.defaults());

      summarySnap = await fakeFirestore
          .doc(FirebaseConstants.statsSummaryPath(storeId))
          .get();
      // Expected totalBalance: 2590.0 + 500.0 = 3090.0
      expect(summarySnap.data()?[FirebaseConstants.totalBalance], 3090.0);
    });
  });
}
