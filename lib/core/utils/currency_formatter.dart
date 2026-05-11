import 'package:intl/intl.dart';

/// A utility class for formatting currency and amounts.
class CurrencyFormatter {
  /// The active locale for currency formatting.
  /// Initialized to 'en_US' as a safe default; call [setLocale] at app startup.
  static String _locale = 'en_US';

  /// Configures the locale used by all formatting methods.
  /// Should be called once during app initialization.
  static void setLocale(String locale) {
    _locale = locale;
  }

  /// Formats a number as a currency amount with thousand separators.
  static String formatAmount(num? amount,
      {bool showCurrency = false, String? currencySymbol}) {
    if (amount == null) {
      return '0.00';
    }
    
    if (showCurrency) {
      final formatter = NumberFormat.currency(
        locale: _locale,
        name: 'EGP',
        symbol: currencySymbol,
        decimalDigits: 2,
      );
      return formatter.format(amount);
    } else {
      final formatter = NumberFormat('#,##0.00', _locale);
      return formatter.format(amount);
    }
  }

  /// Parses a string containing a formatted amount into a double.
  /// Removes common currency symbols, commas, and whitespace.
  static double parseAmount(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 0.0;
    }
    // Remove common currency symbols (ج.م., EGP, $, etc.), commas, and whitespace.
    // Replace anything that is not a digit or a dot with an empty string.
    var cleanedText = text.replaceAll(RegExp(r'[^\d.]'), '');
    
    // If there are multiple dots (e.g. from "ج.م."), keep only the first one or the one before the decimal part
    // Actually, it's safer to remove trailing dots.
    while (cleanedText.endsWith('.')) {
      cleanedText = cleanedText.substring(0, cleanedText.length - 1);
    }
    
    return double.tryParse(cleanedText) ?? 0.0;
  }
}
