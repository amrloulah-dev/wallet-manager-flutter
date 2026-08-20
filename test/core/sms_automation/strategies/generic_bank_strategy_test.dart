import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/strategies/generic_bank_strategy.dart';

void main() {
  late GenericBankStrategy strategy;

  setUp(() {
    strategy = GenericBankStrategy();
  });

  group('GenericBankStrategy Parsing', () {
    test('should parse standard amount', () {
      const body = 'transfer received amount of egp 100.0';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 100.0);
    });

    test('should parse amount with comma (fails before fix)', () {
      const body = 'transfer received amount of egp 1,000.0';
      final result = strategy.parse(body);

      // Current implementation will fail to parse 1,000.0 as a double
      expect(result, isNotNull);
      expect(result!.amount, 1000.0);
    });

    test('should parse Arabic deposit (Receive / Credit)', () {
      const body = 'تم تحويل مبلغ 1500.50 ج.م لحسابكم';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 1500.50);
      expect(result.type.name, 'credit');
    });

    test('should parse Arabic send / transfer (Debit)', () {
      const body = 'تم خصم مبلغ 250.75 ج.م من حسابكم';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 250.75);
      expect(result.type.name, 'debit');
    });

    test('should parse Arabic deposit with إضافة keyword (Credit)', () {
      const body = 'تم اضافة مبلغ 1200.00 ج.م لحسابكم';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 1200.0);
      expect(result.type.name, 'credit');
    });

    test('should ignore balance keyword and capture transaction amount on deposit', () {
      const body = 'تم تحويل من 01012345678 مبلغ 400.00 ج.م رصيدك المتاح 3000.00 ج.م';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 400.0);
      expect(result.type.name, 'credit');
    });

    test('should ignore balance keyword and capture transaction amount on debit', () {
      const body = 'تم خصم مبلغ 150.00 ج.م من حسابكم رصيد الحساب الحالي 10000.00 ج.م';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 150.0);
      expect(result.type.name, 'debit');
    });

    test('should return null on invalid amount format silently', () {
      const body = 'transfer received amount of egp invalid';
      final result = strategy.parse(body);
      expect(result, isNull);
    });
  });

  group('canParse', () {
    test('should return true for IPN sender', () {
      expect(strategy.canParse('IPN'), isTrue);
    });
    test('should return true for INSTAPAY sender', () {
      expect(strategy.canParse('INSTAPAY'), isTrue);
    });
    test('should return true for Arabic InstaPay sender', () {
      expect(strategy.canParse('انستاباي'), isTrue);
      expect(strategy.canParse('إنستاباي'), isTrue);
    });
    test('should return true for Egyptian mobile number senders', () {
      expect(strategy.canParse('01012345678'), isTrue);
      expect(strategy.canParse('+201112345678'), isTrue);
      expect(strategy.canParse('01212345678'), isTrue);
      expect(strategy.canParse('01512345678'), isTrue);
    });
    test('should return false for arbitrary invalid numbers or unknown names', () {
      expect(strategy.canParse('01912345678'), isFalse); // Invalid prefix 019
      expect(strategy.canParse('12345'), isFalse);
      expect(strategy.canParse('RandomService'), isFalse);
    });
  });
}
