import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/models/parsed_sms_dto.dart';
import 'package:walletmanager/core/sms_automation/sms_parser_engine.dart';

void main() {
  group('SmsParserEngine Diagnostics [TEMP DIAGNOSTIC]', () {
    late SmsParserEngine engine;

    setUp(() {
      engine = SmsParserEngine();
    });

    test('should set lastRejection to UNKNOWN_SENDER when sender fails validation', () {
      final result = engine.parse('UnknownSpamService', 'تم استلام مبلغ 500 جنيه من 01012345678');
      expect(result, isNull);
      expect(engine.lastRejection, isNotNull);
      expect(engine.lastRejection!.reason, 'UNKNOWN_SENDER');
      expect(engine.lastRejection!.failureStep, contains('SENDER_VALIDATION'));
    });

    test('should set lastRejection to AMOUNT_NOT_FOUND when anchor regex fails', () {
      // Valid sender, but body has no amount anchor
      final result = engine.parse('VF-Cash', 'تم تحويل رصيد شكرا لاستخدامكم فودافون كاش');
      expect(result, isNull);
      expect(engine.lastRejection, isNotNull);
      expect(engine.lastRejection!.reason, 'AMOUNT_NOT_FOUND');
      expect(engine.lastRejection!.failureStep, contains('تم تحويل رصيد'));
    });

    test('should set lastRejection to TYPE_UNRESOLVED when debit/credit is ambiguous', () {
      // Valid sender, has amount, but no clear credit or debit context
      final result = engine.parse('VF-Cash', 'مبلغ 500 جنيه من 01012345678');
      expect(result, isNull);
      expect(engine.lastRejection, isNotNull);
      expect(engine.lastRejection!.reason, 'TYPE_UNRESOLVED');
    });

    test('should clear lastRejection to null on successful parse', () {
      // First fail
      engine.parse('UnknownSender', 'مرحبا');
      expect(engine.lastRejection, isNotNull);

      // Then succeed
      final result = engine.parse('VF-Cash', 'تم استلام مبلغ 500 جنيه من رقم 01012345678');
      expect(result, isNotNull);
      expect(result!.amount, 500.0);
      expect(result.type, TransactionType.credit);
      expect(engine.lastRejection, isNull);
    });
  });
}
