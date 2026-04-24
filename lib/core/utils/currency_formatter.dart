import 'package:intl/intl.dart';

/// A utility class for formatting currency and amounts.
class CurrencyFormatter {
  /// Formats a number as a currency amount with thousand separators.
  /// Defaults to 'en_US' locale for standard comma separators.
  static String formatAmount(num? amount, {bool showCurrency = false, String currencySymbol = 'ج'}) {
    if (amount == null) {
      return '0';
    }
    final formatter = NumberFormat('#,##0.##', 'en_US');
    final formatted = formatter.format(amount);
    
    if (showCurrency) {
      return '$formatted $currencySymbol';
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
