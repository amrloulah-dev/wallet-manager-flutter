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
  });
}
