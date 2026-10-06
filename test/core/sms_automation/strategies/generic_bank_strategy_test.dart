import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';
import 'package:walletmanager/core/sms_automation/strategies/generic_bank_strategy.dart';
import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';

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

    test('should parse standard decimal amount with dot', () {
      const body = 'transfer received amount of egp 1000.0';
      final result = strategy.parse(body);

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

    test(
        'should ignore balance keyword and capture transaction amount on deposit',
        () {
      const body =
          'تم تحويل من 01012345678 مبلغ 400.00 ج.م رصيدك المتاح 3000.00 ج.م';
      final result = strategy.parse(body);
      expect(result, isNotNull);
      expect(result!.amount, 400.0);
      expect(result.type.name, 'credit');
    });

    test(
        'should ignore balance keyword and capture transaction amount on debit',
        () {
      const body =
          'تم خصم مبلغ 150.00 ج.م من حسابكم رصيد الحساب الحالي 10000.00 ج.م';
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
    test('should return true for case-insensitive bank senders', () {
      expect(strategy.canParse('instapay'), isTrue);
      expect(strategy.canParse('bm'), isTrue);
      expect(strategy.canParse('nbe'), isTrue);
      expect(strategy.canParse('cib'), isTrue);
    });
    test('should return false for arbitrary invalid numbers or unknown names',
        () {
      expect(strategy.canParse('01912345678'), isFalse); // Invalid prefix 019
      expect(strategy.canParse('12345'), isFalse);
      expect(strategy.canParse('RandomService'), isFalse);
    });
  });

  group('Instant Payment Network (IPN / InstaPay) Transfers', () {
    test('parses real-world IPN credit sample with masked account reference',
        () {
      const rawBody =
          'تم اضافة مبلغ 6400EGP        الى حساب رقم xxx0006       فى 04-OCT-2026  عن طريق التحويل اللحظي';
      final normalizedBody = TextNormalizer.normalize(rawBody);
      final result = strategy.parse(normalizedBody, 'InstaPay');

      expect(result, isNotNull);
      expect(result!.amount, 6400.0);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, 'xxx0006');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('parses real-world IPN debit sample with masked account reference',
        () {
      const rawBody =
          'تم تحويل مبلغ 900EGP        من حساب رقم xxx0006       فى 04-OCT-2026  عن طريق التحويل اللحظي';
      final normalizedBody = TextNormalizer.normalize(rawBody);
      final result = strategy.parse(normalizedBody, 'BM');

      expect(result, isNotNull);
      expect(result!.amount, 900.0);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, 'xxx0006');
      expect(result.serviceProvider, 'IPN/Bank');
    });

    test('parses IPN transfer with account reference containing hyphens', () {
      const rawBody =
          'تم اضافة مبلغ 1500 LE الى حساب رقم xxx-0006 فى 04-OCT-2026';
      final normalizedBody = TextNormalizer.normalize(rawBody);
      final result = strategy.parse(normalizedBody, 'NBE');

      expect(result, isNotNull);
      expect(result!.amount, 1500.0);
      expect(result.type, TransactionType.credit);
      expect(result.counterpartyNumber, 'xxx-0006');
    });

    test(
        'end-to-end SmsParserEngine parses IPN transfer with lowercase and uppercase senders',
        () {
      final engine = SmsParserEngine();
      const creditBody =
          'تم اضافة مبلغ 6400EGP        الى حساب رقم xxx0006       فى 04-OCT-2026  عن طريق التحويل اللحظي';
      final creditResult = engine.parse('instapay', creditBody);
      expect(creditResult, isNotNull);
      expect(creditResult!.amount, 6400.0);
      expect(creditResult.type, TransactionType.credit);
      expect(creditResult.counterpartyNumber, 'xxx0006');

      const debitBody =
          'تم تحويل مبلغ 900EGP        من حساب رقم xxx0006       فى 04-OCT-2026  عن طريق التحويل اللحظي';
      final debitResult = engine.parse('BM', debitBody);
      expect(debitResult, isNotNull);
      expect(debitResult!.amount, 900.0);
      expect(debitResult.type, TransactionType.debit);
      expect(debitResult.counterpartyNumber, 'xxx0006');
    });
  });
}
