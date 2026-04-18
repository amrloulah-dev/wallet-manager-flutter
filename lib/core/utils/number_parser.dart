class NumberParser {
  /// Safely parses [value] to a double.
  /// Handles num types directly, parses strings, and falls back to [defaultValue] for null or invalid inputs.
  /// Removes commas from strings before parsing.
  static double toDouble(dynamic value, [double defaultValue = 0.0]) {
    if (value == null) return defaultValue;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? defaultValue;
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
      final cleaned = value.replaceAll(',', '').trim();
      return int.tryParse(cleaned) ?? defaultValue;
    }
    return defaultValue;
  }
}
