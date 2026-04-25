import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/strategies/vodafone_cash_strategy.dart';

void main() {
  late VodafoneCashStrategy strategy;

  setUp(() {
    strategy = VodafoneCashStrategy();
  });

  group('VodafoneCashStrategy Parsing', () {
    test('should parse standard amount', () {
      const body = 'received 100 egp from 01012345678';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 100.0);
    });

    test('should parse amount with comma', () {
      const body = 'received 1,000 egp from 01012345678';
      final result = strategy.parse(body);
      
      // Current implementation might fail this if it doesn't handle commas
      expect(result, isNotNull);
      expect(result!.amount, 1000.0);
    });

    test('should return null on invalid amount format silently (swallowed before fix)', () {
      const body = 'received invalid_amount egp from 01012345678';
      // The current code has a catch (_) {} so it returns null
      final result = strategy.parse(body);
      expect(result, isNull);
    });
  });
}
