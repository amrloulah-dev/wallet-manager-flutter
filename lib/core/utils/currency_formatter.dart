import 'package:intl/intl.dart';

/// A utility class for formatting currency and amounts.
class CurrencyFormatter {
  /// The active locale for currency formatting.
  /// Initialized to 'en_US' as a safe default; call [setLocale] at app startup.
  static String _locale = 'en_US';

  /// The active currency symbol.
  /// Initialized to 'ج' as a safe default; call [setLocale] to configure.
  static String _currencySymbol = 'ج';

  /// Configures the locale and currency symbol used by all formatting methods.
  /// Should be called once during app initialization.
  static void setLocale(String locale, {required String currencySymbol}) {
    _locale = locale;
    _currencySymbol = currencySymbol;
  }

  /// Formats a number as a currency amount with thousand separators.
  static String formatAmount(num? amount,
      {bool showCurrency = false, String? currencySymbol}) {
    if (amount == null) {
      return '0.00';
    }
    final formatter = NumberFormat('#,##0.00', _locale);
    final formatted = formatter.format(amount);

    if (showCurrency) {
      final symbol = currencySymbol ?? _currencySymbol;
      return '$formatted $symbol';
    }
    return formatted;
  }

  /// Parses a string containing a formatted amount into a double.
  /// Removes common currency symbols, commas, and whitespace.
  static double parseAmount(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 0.0;
    }
    // Remove common currency symbols (ج, EGP, $, etc.), commas, and whitespace.
    final cleanedText = text.replaceAll(RegExp(r'[ج,EGP\$\s]'), '');
    return double.tryParse(cleanedText) ?? 0.0;
  }
}
