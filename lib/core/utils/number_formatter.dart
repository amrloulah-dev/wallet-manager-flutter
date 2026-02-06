import 'package:intl/intl.dart';

class NumberFormatter {
  // ===========================
  // Format Number with Commas (1000 → 1,000)
  // ===========================
  /// Formats a number with thousand separators.
  /// Handles null by returning '0'.
  /// Uses 'en_US' locale for standard comma separators.
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
  /// Defaults to 'ج' for the currency symbol.
  static String formatAmount(num? amount,
      {bool showCurrency = true, String currencySymbol = 'ج'}) {
    final formatted = formatNumber(amount ?? 0);
    return formatted; // Temporarily remove currency symbol
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
    if (text == null || text.trim().isEmpty) {
      return 0.0;
    }
    // Remove currency symbols (ج, EGP), commas, and whitespace.
    final cleanedText = text.replaceAll(RegExp(r'[ج,EGP\s]'), '');
    return double.tryParse(cleanedText) ?? 0.0;
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
    // Format pattern: 0XXX XXX XXXX
    if (phone.length == 11) {
      return '${phone.substring(7)} ${phone.substring(4, 7)} ${phone.substring(0, 4)}';
    }
    return phone;
  }
}
