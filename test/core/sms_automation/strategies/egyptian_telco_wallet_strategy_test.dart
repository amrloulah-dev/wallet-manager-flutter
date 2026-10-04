import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';
import 'package:walletmanager/core/sms_automation/strategies/vodafone_cash_strategy.dart';
import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';

void main() {
  late EgyptianTelcoWalletStrategy strategy;

  setUp(() {
    strategy = EgyptianTelcoWalletStrategy();
  });

  group('EgyptianTelcoWalletStrategy - Sender Detection (M-1)', () {
    test('recognizes Vodafone Cash sender variations in English and Arabic', () {
      expect(strategy.canParse('VF-Cash'), isTrue);
      expect(strategy.canParse('vodafone'), isTrue);
      expect(strategy.canParse('vfcash'), isTrue);
      expect(strategy.canParse('فودافون'), isTrue);
      expect(strategy.canParse('فودافون كاش'), isTrue);
      expect(strategy.canParse('فودافونكاش'), isTrue);
    });

    test('recognizes Orange Cash sender variations in English and Arabic', () {
      expect(strategy.canParse('Orange'), isTrue);
      expect(strategy.canParse('orangecash'), isTrue);
      expect(strategy.canParse('orange cash'), isTrue);
      expect(strategy.canParse('اورانج'), isTrue);
      expect(strategy.canParse('أورانج'), isTrue);
      expect(strategy.canParse('اورانج كاش'), isTrue);
      expect(strategy.canParse('أورانج كاش'), isTrue);
    });

    test('recognizes Etisalat Cash sender variations in English and Arabic', () {
      expect(strategy.canParse('Etisalat'), isTrue);
      expect(strategy.canParse('etisalatcash'), isTrue);
      expect(strategy.canParse('etisalat cash'), isTrue);
      expect(strategy.canParse('اتصالات'), isTrue);
      expect(strategy.canParse('اتصالات كاش'), isTrue);
      expect(strategy.canParse('اتصالاتكاش'), isTrue);
    });

    test('recognizes WE Pay sender variations in English and Arabic', () {
      expect(strategy.canParse('WE'), isTrue);
      expect(strategy.canParse('wepay'), isTrue);
      expect(strategy.canParse('we pay'), isTrue);
      expect(strategy.canParse('وي'), isTrue);
      expect(strategy.canParse('وي باي'), isTrue);
      expect(strategy.canParse('ويباي'), isTrue);
    });

    test('rejects unrecognized senders', () {
      expect(strategy.canParse('CIB'), isFalse);
      expect(strategy.canParse('UNKNOWN_SENDER'), isFalse);
    });
  });

  group('EgyptianTelcoWalletStrategy - Dynamic Provider Resolution (M-1)', () {
    test('dynamically sets Orange Cash as serviceProvider for Orange sender', () {
      expect(strategy.canParse('Orange'), isTrue);
      const body = 'تم استلام مبلغ 150 جنيه من 01234567890';
      final result = strategy.parse(body, 'Orange');
      expect(result, isNotNull);
      expect(result!.amount, 150.0);
      expect(result.serviceProvider, 'Orange Cash');
      expect(result.counterpartyNumber, '01234567890');
      expect(result.type.name, 'credit');
    });

    test('dynamically sets Etisalat Cash as serviceProvider for Etisalat sender', () {
      expect(strategy.canParse('Etisalat'), isTrue);
      const body = 'تم استلام مبلغ 250 جنيه من 01134567890';
      final result = strategy.parse(body, 'Etisalat');
      expect(result, isNotNull);
      expect(result!.amount, 250.0);
      expect(result.serviceProvider, 'Etisalat Cash');
      expect(result.counterpartyNumber, '01134567890');
      expect(result.type.name, 'credit');
    });

    test('dynamically sets WE Pay as serviceProvider for WE sender', () {
      expect(strategy.canParse('WE'), isTrue);
      const body = 'تم تحويل مبلغ 350 جنيه إلى 01534567890';
      final result = strategy.parse(body, 'WE');
      expect(result, isNotNull);
      expect(result!.amount, 350.0);
      expect(result.serviceProvider, 'WE Pay');
      expect(result.counterpartyNumber, '01534567890');
      expect(result.type.name, 'debit');
    });

    test('dynamically sets Vodafone Cash as serviceProvider for Vodafone sender', () {
      expect(strategy.canParse('VF-Cash'), isTrue);
      const body = 'تم تحويل مبلغ 50 جنيه إلى 01012345678';
      final result = strategy.parse(body, 'VF-Cash');
      expect(result, isNotNull);
      expect(result!.amount, 50.0);
      expect(result.serviceProvider, 'Vodafone Cash');
      expect(result.counterpartyNumber, '01012345678');
      expect(result.type.name, 'debit');
    });
  });

  group('VodafoneCashStrategy Backwards Compatibility', () {
    test('VodafoneCashStrategy alias instantiates and functions identically', () {
      final legacy = VodafoneCashStrategy();
      expect(legacy.canParse('vodafone'), isTrue);
      expect(legacy.canParse('orange'), isTrue);
      final result = legacy.parse('received 100 egp from 01012345678');
      expect(result, isNotNull);
      expect(result!.amount, 100.0);
    });
  });

  group('Debit Resolution for "تم ارسال" and "الي رقم"', () {
    test('EgyptianTelcoWalletStrategy parses outbound debit with "تم ارسال" and "الي رقم" correctly', () {
      const rawBody =
          'تم ارسال مبلغ 2500.00 جنيه الي رقم 01126483659; المسجل باسم  عادل. رصيدك الحالي 25000.28 جنيه.';
      final normalizedBody = TextNormalizer.normalize(rawBody);
      final result = strategy.parse(normalizedBody, 'WE');

      expect(result, isNotNull);
      expect(result!.amount, 2500.0);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, '01126483659');
      expect(result.serviceProvider, 'WE Pay');
    });

    test('SmsParserEngine parses outbound debit with "تم ارسال" and "الي رقم" correctly', () {
      final engine = SmsParserEngine();
      const rawBody =
          'تم ارسال مبلغ 2500.00 جنيه الي رقم 01126483659; المسجل باسم  عادل. رصيدك الحالي 25000.28 جنيه.';
      final result = engine.parse('WE Pay', rawBody);

      expect(result, isNotNull);
      expect(result!.amount, 2500.0);
      expect(result.type, TransactionType.debit);
      expect(result.counterpartyNumber, '01126483659');
      expect(result.serviceProvider, 'WE Pay');
      expect(engine.lastRejection, isNull);
    });
  });
}

