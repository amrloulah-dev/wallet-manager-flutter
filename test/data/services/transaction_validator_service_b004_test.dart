import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/services/transaction_validator_service.dart';

// A subclass to allow injecting a fake firestore
class TestTransactionValidatorService extends TransactionValidatorService {
  TestTransactionValidatorService(FirebaseFirestore fakeFirestore) : super(firestore: fakeFirestore);
}

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late TestTransactionValidatorService service;
  late String walletId;
  late String storeId;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    service = TestTransactionValidatorService(fakeFirestore);
    walletId = 'test_wallet';
    storeId = 'test_store';
  });

  test('Bug B-004: validateAndSave should throw ValidationException for inactive wallet', () async {
    // 1. Setup: Create an INACTIVE wallet in fake firestore
    final walletRef = fakeFirestore.collection(FirebaseConstants.walletsCollection).doc(walletId);
    await walletRef.set({
      FirebaseConstants.storeId: storeId,
      FirebaseConstants.phoneNumber: '01012345678',
      FirebaseConstants.walletType: 'vodafone_cash',
      FirebaseConstants.walletStatus: 'old',
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
      transactionType: 'send',
      amount: 100.0,
      commission: 5.0,
      serviceFee: 1.0,
      paymentStatus: 'paid',
      transactionDate: DateTime.now(),
      createdAt: DateTime.now(),
      createdBy: 'user1',
    );

    // 2. Act & Assert: Expect ValidationException with specific message
    // CURRENT BEHAVIOR (Buggy): It should NOT throw (or throw something else if it proceeds to limit checks, but it will probably succeed in the fake)
    // DESIRED BEHAVIOR (Fixed): It should throw ValidationException
    
    try {
      await service.validateAndSave(transaction);
      // If we reach here, it means it didn't throw, which is the BUG.
      fail('Should have thrown ValidationException for inactive wallet');
    } on ValidationException catch (e) {
      expect(e.message, contains('المحفظة غير مفعلة أو تم حذفها'));
    } catch (e) {
      fail('Expected ValidationException but got $e');
    }
  });
}
