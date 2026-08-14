import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';

void main() {
  group('SmsParserEngine Fail-Fast Guard Tests', () {
    late SmsParserEngine engine;

    setUp(() {
      engine = SmsParserEngine();
    });

    test('should reject unknown senders immediately (fail-fast) even with transaction keywords', () {
      const spoofedBody = 'Transfer Received Amount of EGP 5000 from 01000000000';
      
      // Senders that are not in bank list and not valid telecom/phone
      expect(engine.parse('MarketingCorp', spoofedBody), isNull);
      expect(engine.parse('RandomSpam123', spoofedBody), isNull);
      expect(engine.parse('MyFriend', spoofedBody), isNull);
      expect(engine.parse('UNKNOWN_GATEWAY', spoofedBody), isNull);
      expect(engine.parse('1234', spoofedBody), isNull);
      expect(engine.parse('0233445566', spoofedBody), isNull); // Landline
    });

    test('should validate recognized telecom sender triggers (English & Arabic)', () {
      // English Triggers
      expect(engine.isValidSender('VF-Cash'), isTrue);
      expect(engine.isValidSender('vf-cash'), isTrue);
      expect(engine.isValidSender('Vodafone'), isTrue);
      expect(engine.isValidSender('vfcash'), isTrue);
      expect(engine.isValidSender('Orange'), isTrue);
      expect(engine.isValidSender('Etisalat'), isTrue);
      expect(engine.isValidSender('WE'), isTrue);
      expect(engine.isValidSender('WE Pay'), isTrue);

      // Arabic Triggers
      // Vodafone
      expect(engine.isValidSender('فودافون'), isTrue);
      expect(engine.isValidSender('فودافونكاش'), isTrue);
      expect(engine.isValidSender('فودافون كاش'), isTrue);

      // InstaPay
      expect(engine.isValidSender('انستاباي'), isTrue);
      expect(engine.isValidSender('إنستاباي'), isTrue);
      expect(engine.isValidSender('انستا باي'), isTrue);
      expect(engine.isValidSender('إنستا باي'), isTrue);

      // Orange
      expect(engine.isValidSender('اورانج'), isTrue);
      expect(engine.isValidSender('أورانج'), isTrue);
      expect(engine.isValidSender('اورانجكاش'), isTrue);
      expect(engine.isValidSender('أورانجكاش'), isTrue);
      expect(engine.isValidSender('اورانج كاش'), isTrue);
      expect(engine.isValidSender('أورانج كاش'), isTrue);

      // Etisalat
      expect(engine.isValidSender('اتصالات'), isTrue);
      expect(engine.isValidSender('اتصالاتكاش'), isTrue);
      expect(engine.isValidSender('اتصالات كاش'), isTrue);

      // WE
      expect(engine.isValidSender('وي'), isTrue);
      expect(engine.isValidSender('ويباي'), isTrue);
      expect(engine.isValidSender('وي باي'), isTrue);
    });

    test('should validate supported bank and aggregator senders', () {
      expect(engine.isValidSender('CIB'), isTrue);
      expect(engine.isValidSender('NBE'), isTrue);
      expect(engine.isValidSender('BM'), isTrue);
      expect(engine.isValidSender('BANQUE MISR'), isTrue);
      expect(engine.isValidSender('QNB'), isTrue);
      expect(engine.isValidSender('ALEXBANK'), isTrue);
      expect(engine.isValidSender('AAIB'), isTrue);
      expect(engine.isValidSender('HSBC'), isTrue);
      expect(engine.isValidSender('IPN'), isTrue);
      expect(engine.isValidSender('InstaPay'), isTrue);
    });

    test('should validate Egyptian mobile numbers in various formats', () {
      expect(engine.isValidSender('01012345678'), isTrue);
      expect(engine.isValidSender('01112345678'), isTrue);
      expect(engine.isValidSender('01212345678'), isTrue);
      expect(engine.isValidSender('01512345678'), isTrue);
      expect(engine.isValidSender('+201012345678'), isTrue);
      expect(engine.isValidSender('201112345678'), isTrue);
      expect(engine.isValidSender('010-1234-5678'), isTrue);
    });

    test('should parse legitimate transactions from authorized senders', () {
      // Vodafone Cash
      final vfResult = engine.parse('VF-Cash', 'تم استلام مبلغ 500 جنيه من رقم 01012345678');
      expect(vfResult, isNotNull);
      expect(vfResult!.amount, 500.0);
      expect(vfResult.type, TransactionType.credit);
      expect(vfResult.serviceProvider, 'Vodafone Cash');

      // Bank
      final bankResult = engine.parse('CIB', 'Transfer Received Amount of EGP 2500');
      expect(bankResult, isNotNull);
      expect(bankResult!.amount, 2500.0);
      expect(bankResult.type, TransactionType.credit);
      expect(bankResult.serviceProvider, 'IPN/Bank');
    });

    test('should return null for authorized sender with non-transaction text', () {
      final result = engine.parse('VF-Cash', 'رصيدك الحالي هو 50 جنيه');
      expect(result, isNull);
    });
  });
}
