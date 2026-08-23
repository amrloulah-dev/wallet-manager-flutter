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

    test('should preserve dots and NOT convert Arabic/thousands commas to dots', () {
      expect(TextNormalizer.normalize('10.50'), '10.50');
      expect(TextNormalizer.normalize('١٠.٥٠'), '10.50');
      // Comma is preserved as-is and not altered
      expect(TextNormalizer.normalize('10,50'), '10,50');
      expect(TextNormalizer.normalize('1,000.50'), '1,000.50');
    });

    test('should convert to lowercase and collapse whitespace', () {
      expect(TextNormalizer.normalize('HELLO   WORLD'), 'hello world');
    });
  });

  group('VodafoneCashStrategy', () {
    final strategy = VodafoneCashStrategy();

    test('should parse deposit (Receive / Credit)', () {
      const body = 'تم استلام مبلغ 1000 جنيه من رقم 01012345678';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 1000.0);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, '01012345678');
      expect(result.serviceProvider, 'Vodafone Cash');
    });

    test('should parse transfer (Send / Debit)', () {
      const body = 'تم تحويل مبلغ 50.50 جنيه إلى رقم 01012345678';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 50.50);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, '01012345678');
      expect(result.serviceProvider, 'Vodafone Cash');
    });

    test('should return null for irrelevant messages or OTPs', () {
      const body = 'Your OTP is 1234';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);
      expect(result, isNull);
    });

    test('should return null for ambiguous transfer without directional compound context', () {
      const body = 'تم تحويل 500 جنيه';
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
      expect(result.counterpartyNumber, 'IPN/Bank');
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
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse from IPN triggers', () {
      expect(strategy.canParse('IPN'), isTrue);
      expect(strategy.canParse('InstaPay'), isTrue);
      expect(strategy.canParse('انستاباي'), isTrue);
      expect(strategy.canParse('إنستاباي'), isTrue);
    });

    test('should parse Arabic bank deposit (Credit)', () {
      const body = 'تم تحويل مبلغ 1500.50 ج.م لحسابكم';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 1500.50);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse Arabic bank deposit via deposit keyword (Credit)', () {
      const body = 'تم ايداع مبلغ 3000 جنيه في حسابكم';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 3000.0);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse Arabic bank deduction (Debit)', () {
      const body = 'تم خصم مبلغ 450.00 ج.م من حسابكم';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 450.0);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse Arabic bank transfer out (Debit)', () {
      const body = 'تم تحويل مبلغ 800 ج.م من حسابكم';
      final normalizedInfo = TextNormalizer.normalize(body);
      final result = strategy.parse(normalizedInfo);

      expect(result, isNotNull);
      expect(result!.amount, 800.0);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });
  });

  group('SmsParserEngine & False Positive Elimination', () {
    final engine = SmsParserEngine();

    test('should parse Vodafone Cash message via Engine', () {
      final result =
          engine.parse('VF-Cash', 'تم استلام مبلغ 200 جنيه من رقم 01000000000');
      expect(result, isNotNull);
      expect(result!.amount, 200.0);
      expect(result.serviceProvider, 'Vodafone Cash');
      expect(result.counterpartyNumber, '01000000000');
      expect(result.type, TransactionType.credit);
    });

    test('should parse IPN message via Engine', () {
      final result =
          engine.parse('InstaPay', 'Transfer Received Amount of EGP 3000');
      expect(result, isNotNull);
      expect(result!.amount, 3000.0);
      expect(result.serviceProvider, 'IPN/Bank');
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.type, TransactionType.credit);
    });

    test('should parse Bank message via Engine', () {
      final result =
          engine.parse('CIB', 'Transfer Received Amount of EGP 5000');
      expect(result, isNotNull);
      expect(result!.amount, 5000.0);
      expect(result.serviceProvider, 'IPN/Bank');
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.type, TransactionType.credit);
    });

    test('should parse Arabic Bank message via Engine (Credit)', () {
      final result =
          engine.parse('BM', 'تم تحويل مبلغ 1500.50 ج.م لحسابكم');
      expect(result, isNotNull);
      expect(result!.amount, 1500.50);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse Arabic Bank message via Engine (Debit)', () {
      final result =
          engine.parse('NBE', 'تم خصم مبلغ 600.00 ج.م من حسابكم');
      expect(result, isNotNull);
      expect(result!.amount, 600.0);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, 'IPN/Bank');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should parse forwarded/test message from mobile sender with counterparty', () {
      final result = engine.parse(
        '01091264053',
        'محول من 01234567890 مبلغ 2500',
      );

      expect(result, isNotNull);
      expect(result!.amount, 2500.0);
      expect(result.counterpartyNumber, '01234567890');
      expect(result.type, TransactionType.credit);
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('should NOT falsely capture credit card numbers (e.g. 4925) as amount', () {
      final result = engine.parse(
        'CIB',
        'تم خصم مبلغ 250.00 ج.م من بطاقة تنتهي برقم 4925',
      );

      expect(result, isNotNull);
      expect(result!.amount, 250.00, reason: 'Must capture 250.00 preceded by مبلغ, not 4925');
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, 'IPN/Bank');
    });

    test('should reject remaining balance as transaction amount', () {
      final result = engine.parse(
        'VF-Cash',
        'رصيدك الحالي المتبقي هو 500 جنيه',
      );

      expect(result, isNull, reason: 'Balance alert without transaction anchor must return null');
    });

    test('should reject ambiguous single word تحويل without directional compound keywords', () {
      final result = engine.parse(
        'VF-Cash',
        'تم تحويل 500 جنيه بنجاح',
      );

      expect(result, isNull, reason: 'Ambiguous تحويل without anchor and context must be rejected');
    });

    test('should reject comma-separated decimals without dot', () {
      final result = engine.parse(
        'VF-Cash',
        'تم استلام مبلغ 10,50 جنيه من رقم 01012345678',
      );

      // Comma 10,50 only matches integer portion 10 because only dot is allowed as decimal separator
      expect(result, isNotNull);
      expect(result!.amount, 10.0, reason: 'Strict regex only recognizes dots for decimal fractions');
    });

    test('should return null for unknown sender', () {
      final result = engine.parse('UnknownBank', 'You have received 1000');
      expect(result, isNull);
    });
  });
}
