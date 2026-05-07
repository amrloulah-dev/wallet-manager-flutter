class NumberParser {
  /// Safely parses [value] to a double.
  /// Handles num types directly, parses strings, and falls back to [defaultValue] for null or invalid inputs.
  /// Strips all non-numeric characters except for the decimal point before parsing.
  static double toDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Preserve negative sign if it exists anywhere before or between characters
      // but ensure we only keep the first one if multiple exist.
      final isNegative = value.contains('-');
      final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');

      // If there are multiple dots, double.tryParse will fail correctly
      final result = double.tryParse(isNegative ? '-$sanitized' : sanitized);
      return result ?? defaultValue;
    }
    return defaultValue;
  }

  /// Safely parses [value] to an int.
  /// Handles num types directly (truncates doubles), parses strings, and falls back to [defaultValue] for null or invalid inputs.
  /// Removes commas from strings before parsing.
  static int toInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      // Preserve negative sign
      final isNegative = value.contains('-');
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '').trim();
      final result = int.tryParse(isNegative ? '-$cleaned' : cleaned);
      return result ?? defaultValue;
    }
    return defaultValue;
  }
}
