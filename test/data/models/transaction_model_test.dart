import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';

class MockDocumentSnapshot extends Mock
    implements DocumentSnapshot<Map<String, dynamic>> {}

void main() {
  late MockDocumentSnapshot mockSnapshot;

  setUp(() {
    mockSnapshot = MockDocumentSnapshot();
  });

  group('TransactionModel (Phase 3)', () {
    final baseData = {
      'transactionId': 'tx1',
      'walletId': 'w1',
      'transactionType': 'credit',
      'amount': 100.0,
      'commission': 5.0,
      'serviceFee': 0.0,
      'storeId': 's1',
      'createdBy': 'u1',
      'createdAt': Timestamp.now(),
      'transactionDate': Timestamp.now(),
      'customerPhone': '012',
      'paymentStatus': 'paid',
    };

    test('fromFirestore should throw DomainException if amount is negative',
        () {
      final data = Map<String, dynamic>.from(baseData)..['amount'] = -1.0;
      when(() => mockSnapshot.data()).thenReturn(data);
      when(() => mockSnapshot.id).thenReturn('tx1');

      // Should fail once AmountValidator is added to fromMap
      expect(() => TransactionModel.fromFirestore(mockSnapshot),
          throwsA(isA<Exception>()));
    });

    test('fromFirestore should throw DomainException if commission is negative',
        () {
      final data = Map<String, dynamic>.from(baseData)..['commission'] = -1.0;
      when(() => mockSnapshot.data()).thenReturn(data);
      when(() => mockSnapshot.id).thenReturn('tx1');

      expect(() => TransactionModel.fromFirestore(mockSnapshot),
          throwsA(isA<Exception>()));
    });

    group('bypassedLimit tests', () {
      test('constructor should default bypassedLimit to false', () {
        final tx = TransactionModel(
          transactionId: 'tx1',
          storeId: 's1',
          walletId: 'w1',
          transactionType: TransactionType.credit,
          amount: 100.0,
          createdBy: 'u1',
        );
        expect(tx.bypassedLimit, isFalse);
      });

      test('fromMap should parse bypassedLimit from data', () {
        final dataWithBypass = Map<String, dynamic>.from(baseData)..['bypassedLimit'] = true;
        final tx = TransactionModel.fromMap(dataWithBypass, 'tx1');
        expect(tx.bypassedLimit, isTrue);

        final dataWithoutBypass = Map<String, dynamic>.from(baseData)..['bypassedLimit'] = false;
        final tx2 = TransactionModel.fromMap(dataWithoutBypass, 'tx1');
        expect(tx2.bypassedLimit, isFalse);

        final txNoField = TransactionModel.fromMap(baseData, 'tx1');
        expect(txNoField.bypassedLimit, isFalse);
      });

      test('toFirestore should include bypassedLimit', () {
        final tx = TransactionModel(
          transactionId: 'tx1',
          storeId: 's1',
          walletId: 'w1',
          transactionType: TransactionType.credit,
          amount: 100.0,
          createdBy: 'u1',
          bypassedLimit: true,
        );
        final map = tx.toFirestore();
        expect(map['bypassedLimit'], isTrue);
      });

      test('copyWith should override bypassedLimit', () {
        final tx = TransactionModel(
          transactionId: 'tx1',
          storeId: 's1',
          walletId: 'w1',
          transactionType: TransactionType.credit,
          amount: 100.0,
          createdBy: 'u1',
          bypassedLimit: false,
        );
        final txCopied = tx.copyWith(bypassedLimit: true);
        expect(txCopied.bypassedLimit, isTrue);
      });

      test('== and hashCode should include bypassedLimit', () {
        final tx1 = TransactionModel(
          transactionId: 'tx1',
          storeId: 's1',
          walletId: 'w1',
          transactionType: TransactionType.credit,
          amount: 100.0,
          createdBy: 'u1',
          bypassedLimit: true,
        );
        final tx2 = TransactionModel(
          transactionId: 'tx1',
          storeId: 's1',
          walletId: 'w1',
          transactionType: TransactionType.credit,
          amount: 100.0,
          createdBy: 'u1',
          bypassedLimit: true,
        );
        final tx3 = TransactionModel(
          transactionId: 'tx1',
          storeId: 's1',
          walletId: 'w1',
          transactionType: TransactionType.credit,
          amount: 100.0,
          createdBy: 'u1',
          bypassedLimit: false,
        );

        expect(tx1 == tx2, isTrue);
        expect(tx1 == tx3, isFalse);
        expect(tx1.hashCode == tx2.hashCode, isTrue);
        expect(tx1.hashCode == tx3.hashCode, isFalse);
      });
    });
  });
}
