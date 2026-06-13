import 'package:intl/intl.dart';
import 'currency_formatter.dart';

class NumberFormatter {
  /// Configures the locale used by all formatting methods.
  /// Should be called once during app initialization.
  static void setLocale(String locale) {
    // No-op: Enforce en_US for number formatting
  }

  // ===========================
  // Format Number with Commas (1000 → 1,000)
  // ===========================
  /// Formats a number with thousand separators.
  /// Handles null by returning '0'.
  static String formatNumber(num? number) {
    if (number == null) {
      return '0';
    }
    final formatter = NumberFormat('#,##0.##', 'en_US');
    return formatter.format(number);
  }

  // ===========================
  // Format Amount with Currency (5000 → 5,000 ج)
  // ===========================
  /// Formats a number as a currency amount and optionally adds a currency symbol.
  static String formatAmount(num? amount,
      {bool showCurrency = true, String? currencySymbol}) {
    return CurrencyFormatter.formatAmount(amount,
        showCurrency: showCurrency, currencySymbol: currencySymbol);
  }

  // ===========================
  // Format Percentage (0.75 → 75%)
  // ===========================
  /// Converts a double (e.g., 0.75) to a percentage string (e.g., "75%").
  /// Handles null by returning '0%'.
  static String formatPercentage(double? value, {int decimals = 0}) {
    if (value == null) {
      return '0%';
    }
    final percentage = (value * 100).toStringAsFixed(decimals);
    return '$percentage%';
  }

  // ===========================
  // Parse String to Double
  // ===========================
  /// Parses a string containing a formatted amount into a double.
  /// It removes common currency symbols, commas, and whitespace.
  /// Returns 0.0 if the input is null, empty, or invalid.
  static double parseAmount(String? text) {
    return CurrencyFormatter.parseAmount(text);
  }

  static String _convertArabicToEnglishDigits(String input) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var result = input;
    for (var i = 0; i < 10; i++) {
      result = result.replaceAll(arabicDigits[i], englishDigits[i]);
    }
    return result;
  }

  // ===========================
  // Format Phone Number (01012345678 → 0101 234 5678)
  // ===========================
  /// Formats an 11-digit Egyptian phone number into a more readable format.
  /// If the phone number is not 11 digits, it's returned as is.
  static String formatPhoneNumber(String? phone) {
    if (phone == null) {
      return '';
    }
    final normalized =
        _convertArabicToEnglishDigits(phone).replaceAll(RegExp(r'\D'), '');
    if (normalized.length == 11) {
      return '\u200E${normalized.substring(0, 4)} ${normalized.substring(4, 7)} ${normalized.substring(7)}\u200E';
    }
    return '\u200E$phone\u200E';
  }
}
