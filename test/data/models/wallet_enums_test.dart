import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';

void main() {
  group('WalletType.fromString', () {
    test('should correctly parse exact types', () {
      expect(WalletType.fromString('vodafone_cash'),
          equals(WalletType.vodafoneCash));
      expect(WalletType.fromString('instapay'), equals(WalletType.instaPay));
      expect(
          WalletType.fromString('orange_cash'), equals(WalletType.orangeCash));
      expect(WalletType.fromString('etisalat_cash'),
          equals(WalletType.etisalatCash));
      expect(WalletType.fromString('we_pay'), equals(WalletType.wePay));
    });

    test('should parse types with spaces instead of underscores', () {
      expect(WalletType.fromString('vodafone cash'),
          equals(WalletType.vodafoneCash));
      expect(
          WalletType.fromString('orange cash'), equals(WalletType.orangeCash));
      expect(WalletType.fromString('etisalat cash'),
          equals(WalletType.etisalatCash));
      expect(WalletType.fromString('we pay'), equals(WalletType.wePay));
    });

    test('should parse types with mixed case and leading/trailing whitespace',
        () {
      expect(WalletType.fromString('  Vodafone_Cash '),
          equals(WalletType.vodafoneCash));
      expect(
          WalletType.fromString(' INSTAPAY   '), equals(WalletType.instaPay));
      expect(WalletType.fromString('  Orange Cash '),
          equals(WalletType.orangeCash));
      expect(WalletType.fromString('Etisalat_Cash'),
          equals(WalletType.etisalatCash));
      expect(WalletType.fromString('we pay  '), equals(WalletType.wePay));
    });

    test('should parse camelCase and other variations resiliently', () {
      expect(WalletType.fromString('vodafoneCash'),
          equals(WalletType.vodafoneCash));
      expect(WalletType.fromString('instaPay'), equals(WalletType.instaPay));
      expect(
          WalletType.fromString('orangeCash'), equals(WalletType.orangeCash));
      expect(WalletType.fromString('etisalatCash'),
          equals(WalletType.etisalatCash));
      expect(WalletType.fromString('wePay'), equals(WalletType.wePay));
    });

    test('should parse Arabic wallet type names correctly', () {
      expect(WalletType.fromString('فودافون كاش'),
          equals(WalletType.vodafoneCash));
      expect(WalletType.fromString('إنستاباي'), equals(WalletType.instaPay));
      expect(WalletType.fromString('انستاباي'), equals(WalletType.instaPay));
      expect(
          WalletType.fromString('أورانج كاش'), equals(WalletType.orangeCash));
      expect(WalletType.fromString('اتصالات كاش'),
          equals(WalletType.etisalatCash));
      expect(WalletType.fromString('وي باي'), equals(WalletType.wePay));
    });

    test('should default to WalletType.other for unknown strings', () {
      expect(WalletType.fromString('unknown_wallet'), equals(WalletType.other));
      expect(WalletType.fromString(''), equals(WalletType.other));
    });
  });
}
