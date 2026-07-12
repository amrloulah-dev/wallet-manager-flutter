import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/core/utils/currency_formatter.dart';

void main() {
  group('NumberFormatter & CurrencyFormatter TDD Tests', () {
    setUp(() {
      // Set locale to ar to simulate device in Arabic locale
      NumberFormatter.setLocale('ar');
      CurrencyFormatter.setLocale('ar');
    });

    tearDown(() {
      // Restore default
      NumberFormatter.setLocale('en_US');
      CurrencyFormatter.setLocale('en_US');
    });

    test(
        'formatNumber should strictly use English (Western) digits and smart decimals',
        () {
      // Integers should drop decimals entirely
      expect(NumberFormatter.formatNumber(1500), equals('1,500'));
      expect(NumberFormatter.formatNumber(1500.0), equals('1,500'));
      expect(NumberFormatter.formatNumber(0), equals('0'));

      // Decimals should be kept
      expect(NumberFormatter.formatNumber(1500.75), equals('1,500.75'));
      expect(NumberFormatter.formatNumber(1500.5), equals('1,500.5'));
    });

    test('formatAmount should strictly use English digits and smart decimals',
        () {
      // Without currency symbol, formatAmount delegates to CurrencyFormatter
      expect(NumberFormatter.formatAmount(1500, showCurrency: false),
          equals('1,500'));
      expect(NumberFormatter.formatAmount(1500.75, showCurrency: false),
          equals('1,500.75'));
      expect(NumberFormatter.formatAmount(1500.0, showCurrency: false),
          equals('1,500'));

      // With currency symbol
      final formatted = NumberFormatter.formatAmount(1500, showCurrency: true);
      // It should contain '1,500' (no decimals) and the currency name/symbol in English locale format
      expect(formatted, contains('1,500'));
      expect(formatted, isNot(contains('.00')));
    });

    test(
        'formatPhoneNumber should strictly use English digits and not add thousands separators',
        () {
      expect(NumberFormatter.formatPhoneNumber('01012345678'),
          equals('\u200E0101 234 5678\u200E'));
      expect(NumberFormatter.formatPhoneNumber('01234567890'),
          equals('\u200E0123 456 7890\u200E'));
      // Messy input with Arabic digits or extra spaces should be handled
      expect(NumberFormatter.formatPhoneNumber('٠١٠١٢٣٤٥٦٧٨'),
          equals('\u200E0101 234 5678\u200E'));
      expect(NumberFormatter.formatPhoneNumber('12345'),
          equals('\u200E12345\u200E'));
    });
  });
}
