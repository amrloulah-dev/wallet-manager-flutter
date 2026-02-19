import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';
import 'package:walletmanager/core/sms_automation/strategies/generic_bank_strategy.dart';
import 'package:walletmanager/core/sms_automation/strategies/vodafone_cash_strategy.dart';
import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer', () {
    test('should normalize Arabic characters', () {
      expect(TextNormalizer.normalize('أ'), 'ا');
      expect(TextNormalizer.normalize('إ'), 'ا');
      expect(TextNormalizer.normalize('آ'), 'ا');
      expect(TextNormalizer.normalize('ة'), 'ه');
      expect(TextNormalizer.normalize('ى'), 'ي');
    });

    test('should convert Arabic numerals to English', () {
      expect(TextNormalizer.normalize('١٢٣٤٥٦٧٨٩٠'), '1234567890');
    });

    test('should remove commas from numbers', () {
      expect(TextNormalizer.normalize('1,000'), '1000');
      expect(TextNormalizer.normalize('10,000.50'), '10000.50');
    });

    test('should convert to lowercase', () {
      expect(TextNormalizer.normalize('HELLO'), 'hello');
    });
  });

  group('VodafoneCashStrategy', () {
    final strategy = VodafoneCashStrategy();

    test('should parse deposit (Receive)', () {
      const body = 'تم استلام مبلغ 1000 جنيه من رقم 01012345678';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 1000.0);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, '01012345678');
      expect(result.serviceProvider, 'Vodafone Cash');
    });

    test('should parse transfer (Send)', () {
      const body = 'تم تحويل مبلغ 50.50 جنيه إلى رقم 01012345678';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 50.50);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, '01012345678');
      expect(result.serviceProvider, 'Vodafone Cash');
    });

    test('should return null for irrelevant messages', () {
      const body = 'Your OTP is 1234';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);
      expect(result, isNull);
    });
  });

  group('GenericBankStrategy', () {
    final strategy = GenericBankStrategy();

    test('should parse deposit (Receive) from CIB', () {
      const body = 'Transfer Received. Amount of EGP 5000.00';
      final normalizedInfo = TextNormalizer.normalize(body);

      expect(strategy.canParse('CIB'), isTrue);

      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
      expect(result.type, TransactionType.credit);
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse transfer (Send) from NBE', () {
      const body = 'Transfer Sent. Amount of EGP 123.45';
      final normalizedInfo = TextNormalizer.normalize(body);

      expect(strategy.canParse('NBE'), isTrue);

      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 123.45);
      expect(result.type, TransactionType.debit);
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse from IPN triggers', () {
      expect(strategy.canParse('IPN'), isTrue);
      expect(strategy.canParse('InstaPay'), isTrue);
    });
  });

  group('SmsParserEngine', () {
    final engine = SmsParserEngine();

    test('should parse Vodafone Cash message via Engine', () {
      final result =
          engine.parse('VF-Cash', 'تم استلام مبلغ 200 جنيه من رقم 01000000000');
      expect(result, isNotNull);
      expect(result!.amount, 200.0);
      expect(result.serviceProvider, 'Vodafone Cash');
    });

    test('should parse IPN message via Engine', () {
      final result =
          engine.parse('InstaPay', 'Transfer Received Amount of EGP 3000');
      expect(result, isNotNull);
      expect(result!.amount, 3000.0);
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse Bank message via Engine', () {
      final result =
          engine.parse('CIB', 'Transfer Received Amount of EGP 5000');
      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should return null for unknown sender', () {
      final result = engine.parse('UnknownBank', 'You have received 1000');
      expect(result, isNull);
    });
  });
}
