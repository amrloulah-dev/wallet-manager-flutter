import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mocktail/mocktail.dart';

class MockDocumentSnapshot extends Mock implements DocumentSnapshot<Map<String, dynamic>> {}

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

    test('fromFirestore should throw DomainException if amount is negative', () {
      final data = Map<String, dynamic>.from(baseData)..['amount'] = -1.0;
      when(() => mockSnapshot.data()).thenReturn(data);
      when(() => mockSnapshot.id).thenReturn('tx1');
      
      // Should fail once AmountValidator is added to fromMap
      expect(() => TransactionModel.fromFirestore(mockSnapshot), throwsA(isA<Exception>()));
    });

    test('fromFirestore should throw DomainException if commission is negative', () {
      final data = Map<String, dynamic>.from(baseData)..['commission'] = -1.0;
      when(() => mockSnapshot.data()).thenReturn(data);
      when(() => mockSnapshot.id).thenReturn('tx1');

      expect(() => TransactionModel.fromFirestore(mockSnapshot), throwsA(isA<Exception>()));
    });
  });
}
