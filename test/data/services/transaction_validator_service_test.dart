import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:walletmanager/data/services/transaction_validator_service.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
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
      await service.validateAndSave(txModel);

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
      await service.validateAndSave(txModel);

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

      await service.validateAndSave(txModel);

      final todayDate = DateHelper.getCurrentDateString();
      final dailyStatsSnap = await fakeFirestore
          .doc(FirebaseConstants.dailyStatsPath(storeId, todayDate))
          .get();

      expect(dailyStatsSnap.exists, isTrue);
      final data = dailyStatsSnap.data();
      expect(data?['sendCount'], 1);
      expect(data?['totalSentAmount'], 300.0);
    });
  });
}
