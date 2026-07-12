import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/services/transaction_validator_service.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

// A subclass to allow injecting a fake firestore
class TestTransactionValidatorService extends TransactionValidatorService {
  TestTransactionValidatorService(FirebaseFirestore fakeFirestore)
      : super(firestore: fakeFirestore);
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late TestTransactionValidatorService service;
  late String walletId;
  late String storeId;

  setUp(() {
    AppErrorHandler.isTestMode = true;
    fakeFirestore = FakeFirebaseFirestore();
    service = TestTransactionValidatorService(fakeFirestore);
    walletId = 'test_wallet';
    storeId = 'test_store';
  });

  test(
      'Bug B-004: validateAndSave should throw ValidationException for inactive wallet',
      () async {
    // 1. Setup: Create an INACTIVE wallet in fake firestore
    final walletRef = fakeFirestore
        .collection(FirebaseConstants.walletsCollection)
        .doc(walletId);
    await walletRef.set({
      FirebaseConstants.storeId: storeId,
      FirebaseConstants.phoneNumber: '01012345678',
      FirebaseConstants.walletType: WalletType.vodafoneCash.name,
      FirebaseConstants.walletStatus: WalletStatus.active.name,
      'balance': 1000.0,
      FirebaseConstants.isActive: false, // 🚩 Inactive
      FirebaseConstants.createdAt: Timestamp.now(),
      FirebaseConstants.createdBy: 'user1',
      FirebaseConstants.sendLimits: {
        'dailyLimit': 60000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 200000.0,
        'monthlyUsed': 0.0,
      },
      FirebaseConstants.receiveLimits: {
        'dailyLimit': 60000.0,
        'dailyUsed': 0.0,
        'monthlyLimit': 200000.0,
        'monthlyUsed': 0.0,
      },
      FirebaseConstants.lastDailyReset: Timestamp.now(),
      FirebaseConstants.lastMonthlyReset: Timestamp.now(),
      FirebaseConstants.stats: {
        'totalTransactions': 0,
        'totalSentAmount': 0.0,
        'totalReceivedAmount': 0.0,
        'totalCommission': 0.0,
      },
    });

    final transaction = TransactionModel(
      transactionId: 'tx1',
      storeId: storeId,
      walletId: walletId,
      transactionType: TransactionType.debit,
      amount: 100.0,
      commission: 5.0,
      serviceFee: 1.0,
      paymentStatus: PaymentStatus.paid,
      transactionDate: DateTime.now(),
      createdAt: DateTime.now(),
      createdBy: 'user1',
    );

    try {
      await service.validateAndSave(
          transaction, const PlatformSettingsModel.defaults());
      fail('Should have thrown ValidationException for inactive wallet');
    } on ValidationException catch (e) {
      expect(e.message, equals('wallet_error_inactive'));
    } catch (e) {
      fail('Expected ValidationException but got $e');
    }
  });
}
