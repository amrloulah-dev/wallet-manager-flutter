class NumberParser {
  /// Safely parses [value] to a double.
  /// Handles num types directly, parses strings, and falls back to [defaultValue] for null or invalid inputs.
  /// Strips all non-numeric characters except for the decimal point before parsing.
  static double toDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Robust sanitization: Keep only digits and the first decimal point
      final sanitized = value.replaceAll(RegExp(r'[^0-9.]'), '');
      
      // If there are multiple dots, double.tryParse will fail correctly
      return double.tryParse(sanitized) ?? defaultValue;
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
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '').trim();
      return int.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }
}
