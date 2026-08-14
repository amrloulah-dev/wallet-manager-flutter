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

    test('should parse credit with number before amount (flexible pattern)', () {
      const body = 'محول من 01234567890 مبلغ 2500';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 2500.0);
      expect(result.counterpartyNumber, '01234567890');
      expect(result.type.name, 'credit');
    });

    test('should parse debit with flexible directional prefix', () {
      const body = 'تم تحويل مبلغ 50.50 جنيه إلى 01012345678';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 50.50);
      expect(result.counterpartyNumber, '01012345678');
      expect(result.type.name, 'debit');
    });

    test(
        'should return null on invalid amount format silently (swallowed before fix)',
        () {
      const body = 'received invalid_amount egp from 01012345678';
      // The current code has a catch (_) {} so it returns null
      final result = strategy.parse(body);
      expect(result, isNull);
    });
  });

  group('canParse', () {
    test('should return true for telecom triggers', () {
      expect(strategy.canParse('VF-Cash'), isTrue);
      expect(strategy.canParse('Vodafone'), isTrue);
      expect(strategy.canParse('فودافون'), isTrue);
      expect(strategy.canParse('فودافونكاش'), isTrue);
    });

    test('should return true for valid Egyptian mobile numbers', () {
      expect(strategy.canParse('01091264053'), isTrue);
      expect(strategy.canParse('+201012345678'), isTrue);
      expect(strategy.canParse('201112345678'), isTrue);
    });
  });
}
