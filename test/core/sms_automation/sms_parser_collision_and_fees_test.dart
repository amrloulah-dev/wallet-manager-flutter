import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/sms_automation/strategies/egyptian_telco_wallet_strategy.dart';
import 'package:walletmanager/core/sms_automation/utils/text_normalizer.dart';

void main() {
  late EgyptianTelcoWalletStrategy strategy;

  setUp(() {
    strategy = EgyptianTelcoWalletStrategy();
  });

  group('M-2: Fee Clause Noise Stripping (Zero Fee Extraction / No Debit Flip)', () {
    test('credit SMS with fee deduction clause extracts net principal amount and stays Credit', () {
      const raw = 'تم استلام مبلغ 500 جنيه في محفظتك من 01012345678. تم خصم 1 جنيه رسوم الخدمة. رصيدك الحالي 1200 جنيه';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'VF-Cash');

      expect(result, isNotNull, reason: 'SMS should parse successfully without mutual ambiguity deadlock');
      expect(result!.amount, 500.0, reason: 'Amount MUST be 500 EGP principal, fee (1 EGP) must be ignored as noise');
      expect(result.type.name, 'credit', reason: 'Transaction MUST remain Credit despite "تم خصم ... رسوم" clause');
      expect(result.counterpartyNumber, '01012345678');
    });

    test('credit SMS with service fee note preserves Credit and extracts principal', () {
      const raw = 'تم ايداع مبلغ 1000 جنيه في حسابكم مصاريف الخدمة 5 جنيه من 01223456789';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'Orange');

      expect(result, isNotNull);
      expect(result!.amount, 1000.0, reason: 'Must extract 1000 EGP, ignoring 5 EGP service fee');
      expect(result.type.name, 'credit');
      expect(result.counterpartyNumber, '01223456789');
    });

    test('English credit SMS with debited service fee ignores fee and resolves to Credit', () {
      const raw = 'Received 300 EGP from 01223456789. Service fee of 1.50 EGP was debited. Current balance: 1500 EGP';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'Orange');

      expect(result, isNotNull);
      expect(result!.amount, 300.0, reason: 'Must extract 300 EGP net amount');
      expect(result.type.name, 'credit', reason: 'Must not flip to Debit due to debited fee');
    });

    test('debit SMS with transfer fee clause extracts net principal amount and stays Debit', () {
      const raw = 'تم تحويل مبلغ 200 جنيه إلى 01112345678. خصم 2 جنيه رسوم تحويل. رصيدك الحالي 800 جنيه';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'Etisalat');

      expect(result, isNotNull);
      expect(result!.amount, 200.0, reason: 'Amount MUST be 200 EGP, ignoring 2 EGP transfer fee');
      expect(result.type.name, 'debit');
      expect(result.counterpartyNumber, '01112345678');
    });

    test('English debit SMS with debited fee extracts net principal amount', () {
      const raw = 'You have sent 150 EGP to 01098765432. Fee 1.5 EGP debited. Balance: 400 EGP';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'Vodafone');

      expect(result, isNotNull);
      expect(result!.amount, 150.0);
      expect(result.type.name, 'debit');
      expect(result.counterpartyNumber, '01098765432');
    });
  });

  group('M-2: Action Anchor Precedence & Keyword Collision Resolution', () {
    test('incoming transfer with "إلى محفظتك" resolves to Credit without deadlock', () {
      const raw = 'تم استلام تحويل بمبلغ 200 جنيه من 01012345678 إلى محفظتك';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'VF-Cash');

      expect(result, isNotNull, reason: 'Collision between "تحويل إلى" and "استلام" must be resolved');
      expect(result!.type.name, 'credit', reason: '"تم استلام" and "إلى محفظتك" must resolve to Credit');
      expect(result.amount, 200.0);
      expect(result.counterpartyNumber, '01012345678');
    });

    test('incoming transfer with "إلى حسابك" resolves to Credit', () {
      const raw = 'تم استلام مبلغ 400 جنيه محول من 01012345678 إلى حسابك';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'VF-Cash');

      expect(result, isNotNull);
      expect(result!.type.name, 'credit');
      expect(result.amount, 400.0);
    });

    test('supports "بقيمة" anchor for amount extraction', () {
      const raw = 'تم استلام بقيمة 350 جنيه من 01234567890';
      final normalized = TextNormalizer.normalize(raw);
      final result = strategy.parse(normalized, 'Orange');

      expect(result, isNotNull);
      expect(result!.amount, 350.0);
      expect(result.type.name, 'credit');
    });
  });
}
