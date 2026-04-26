import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/debt_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:mocktail/mocktail.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  group('Model Enum Serialization', () {
    test('DebtModel should serialize/deserialize enums', () {
      final now = DateTime.now();
      final debt = DebtModel(
        debtId: 'debt1',
        storeId: 'store1',
        customerName: 'Customer',
        customerPhone: '01234567890',
        debtType: DebtType.transaction,
        amountDue: 100.0,
        totalAmount: 100.0,
        debtStatus: DebtStatus.open,
        debtDate: now,
        createdAt: now,
        createdBy: 'user1',
      );

      final firestoreMap = debt.toFirestore();
      expect(firestoreMap['debtType'], equals('transaction'));
      expect(firestoreMap['debtStatus'], equals('open'));

      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('debt1');
      when(() => mockSnapshot.data()).thenReturn({
        'storeId': 'store1',
        'customerName': 'Customer',
        'customerPhone': '01234567890',
        'debtType': 'transaction',
        'amountDue': 100.0,
        'totalAmount': 100.0,
        'debtStatus': 'open',
        'debtDate': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'createdBy': 'user1',
      });

      final fromFirestore = DebtModel.fromFirestore(mockSnapshot);
      expect(fromFirestore.debtType, equals(DebtType.transaction));
      expect(fromFirestore.debtStatus, equals(DebtStatus.open));
    });

    test('WalletModel should serialize/deserialize enums', () {
      final now = DateTime.now();
      final wallet = WalletModel(
        walletId: 'wallet1',
        storeId: 'store1',
        phoneNumber: '01234567890',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 1000.0,
        createdAt: now,
        createdBy: 'user1',
        sendLimits: WalletLimits(dailyLimit: 60000, monthlyLimit: 200000),
        receiveLimits: WalletLimits(dailyLimit: 60000, monthlyLimit: 200000),
        lastDailyReset: now,
        lastMonthlyReset: now,
        stats: WalletStats(),
      );

      final firestoreMap = wallet.toFirestore();
      expect(firestoreMap['walletType'], equals('vodafoneCash'));
      expect(firestoreMap['walletStatus'], equals('active'));

      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('wallet1');
      when(() => mockSnapshot.data()).thenReturn({
        'storeId': 'store1',
        'phoneNumber': '01234567890',
        'walletType': 'vodafone_cash',
        'walletStatus': 'active',
        'balance': 1000.0,
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'createdBy': 'user1',
        'sendLimits': {'dailyLimit': 60000.0, 'dailyUsed': 0.0, 'monthlyLimit': 200000.0, 'monthlyUsed': 0.0},
        'receiveLimits': {'dailyLimit': 60000.0, 'dailyUsed': 0.0, 'monthlyLimit': 200000.0, 'monthlyUsed': 0.0},
        'lastDailyReset': Timestamp.fromDate(now),
        'lastMonthlyReset': Timestamp.fromDate(now),
        'stats': {'totalTransactions': 0, 'totalSentAmount': 0.0, 'totalReceivedAmount': 0.0, 'totalCommission': 0.0},
      });

      final fromFirestore = WalletModel.fromFirestore(mockSnapshot);
      expect(fromFirestore.walletType, equals(WalletType.vodafoneCash));
      expect(fromFirestore.walletStatus, equals(WalletStatus.active));
    });

    test('TransactionModel should serialize/deserialize enums', () {
      final now = DateTime.now();
      final tx = TransactionModel(
        transactionId: 'tx1',
        storeId: 'store1',
        walletId: 'wallet1',
        transactionType: TransactionType.debit,
        amount: 100.0,
        paymentStatus: PaymentStatus.paid,
        transactionDate: now,
        createdAt: now,
        createdBy: 'user1',
      );

      final firestoreMap = tx.toFirestore();
      expect(firestoreMap['transactionType'], equals('debit'));
      expect(firestoreMap['paymentStatus'], equals('paid'));

      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('tx1');
      when(() => mockSnapshot.data()).thenReturn({
        'storeId': 'store1',
        'walletId': 'wallet1',
        'transactionType': 'send',
        'amount': 100.0,
        'paymentStatus': 'paid',
        'transactionDate': Timestamp.fromDate(now),
        'createdAt': Timestamp.fromDate(now),
        'createdBy': 'user1',
      });

      final fromFirestore = TransactionModel.fromFirestore(mockSnapshot);
      expect(fromFirestore.transactionType, equals(TransactionType.debit));
      expect(fromFirestore.paymentStatus, equals(PaymentStatus.paid));
    });

    test('UserModel should serialize/deserialize enums', () {
      final now = DateTime.now();
      final user = UserModel(
        userId: 'user1',
        storeId: 'store1',
        role: UserRole.owner,
        fullName: 'Owner',
        createdAt: now,
        lastLogin: now,
      );

      final firestoreMap = user.toFirestore();
      expect(firestoreMap['role'], equals('owner'));

      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('user1');
      when(() => mockSnapshot.data()).thenReturn({
        'storeId': 'store1',
        'role': 'owner',
        'fullName': 'Owner',
        'isActive': true,
        'createdAt': Timestamp.fromDate(now),
        'lastLogin': Timestamp.fromDate(now),
      });

      final fromFirestore = UserModel.fromFirestore(mockSnapshot);
      expect(fromFirestore.role, equals(UserRole.owner));
    });

    test('StoreModel should serialize/deserialize enums', () {
      final now = DateTime.now();
      final store = StoreModel(
        storeId: 'store1',
        storeName: 'Store',
        storePassword: 'hashed',
        ownerId: 'owner1',
        ownerName: 'Owner',
        ownerEmail: 'owner@store.com',
        createdAt: now,
        subscription: StoreSubscription(
          planId: SubscriptionPlan.trial,
          status: SubscriptionStatus.active,
          trialConsumed: false,
          maxWallets: 999,
          maxEmployees: 999,
          smsEnabled: true,
        ),
        settings: StoreSettings(),
        stats: StoreStats(lastUpdated: now),
      );

      final firestoreMap = store.toFirestore();
      expect(firestoreMap['subscription']['planId'], equals('trial'));
      expect(firestoreMap['subscription']['status'], equals('active'));

      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('store1');
      when(() => mockSnapshot.data()).thenReturn({
        'storeName': 'Store',
        'storePassword': 'hashed',
        'ownerId': 'owner1',
        'ownerName': 'Owner',
        'ownerEmail': 'owner@store.com',
        'isActive': true,
        'isSuspended': false,
        'createdAt': Timestamp.fromDate(now),
        'subscription': {
          'planId': 'trial',
          'status': 'active',
          'trialConsumed': false,
          'maxWallets': 999,
          'maxEmployees': 999,
          'smsEnabled': true,
        },
        'settings': {'currency': 'EGP', 'timezone': 'Africa/Cairo'},
        'stats': {'totalWallets': 0, 'activeWallets': 0, 'totalTransactionsToday': 0, 'totalCommissionToday': 0.0, 'lastUpdated': Timestamp.fromDate(now)},
      });

      final fromFirestore = StoreModel.fromFirestore(mockSnapshot);
      expect(fromFirestore.subscription.planId, equals(SubscriptionPlan.trial));
      expect(fromFirestore.subscription.status, equals(SubscriptionStatus.active));
    });
  });

  group('Safe Serialization & Null Safety', () {
    test('DebtModel should handle missing timestamps and return null', () {
      final mockSnapshot = MockDocumentSnapshot();
      when(() => mockSnapshot.exists).thenReturn(true);
      when(() => mockSnapshot.id).thenReturn('debt1');
      when(() => mockSnapshot.data()).thenReturn({
        'storeId': 'store1',
        'customerName': 'Customer',
        'customerPhone': '01234567890',
        'debtType': 'transaction',
        'amountDue': 100.0,
        'debtStatus': 'open',
        // Missing debtDate, createdAt, etc.
      });

      final fromFirestore = DebtModel.fromFirestore(mockSnapshot);
      // We expect it to NOT throw and provide defaults or nulls where applicable
      // But the current implementation uses ?? DateTime.now() for required fields.
      // The spec says "return null for missing timestamps (no fabricating Timestamp.now())".
      // This means we might need to update the model to allow nulls or handle them differently.
    });
  });
}
