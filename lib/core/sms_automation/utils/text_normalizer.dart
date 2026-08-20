class TextNormalizer {
  /// Normalizes Arabic characters and cleans text.
  static String normalize(String input) {
    if (input.isEmpty) return input;

    String text = input;

    // 1. Normalize Characters
    // Convert [أإآ] to ا
    text = text.replaceAll(RegExp(r'[أإآ]'), 'ا');
    // Convert ة to ه
    text = text.replaceAll('ة', 'ه');
    // Convert ى to ي
    text = text.replaceAll('ى', 'ي');
    // Convert to lower case
    text = text.toLowerCase();

    // 2. Clean Whitespaces & Newlines
    // Replace all line breaks and multiple spaces with a single space
    // to prevent Regex matching issues.
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 3. Clean Numbers
    // Convert Arabic/Eastern numerals to English/Western numerals
    text = _convertArabicNumeralsToEnglish(text);

    // 4. Protect & Convert Decimal Commas
    // Convert comma to period ONLY when it acts as a decimal separator
    // (i.e. followed by exactly 1 or 2 digits not followed by another digit).
    // e.g. "10,50" -> "10.50", "5,5" -> "5.5", "1,500,50" -> "1,500.50"
    text = text.replaceAll(RegExp(r',(?=\d{1,2}(?!\d))'), '.');

    // 5. Clean Thousands Separators
    // Remove surviving commas that act as thousands separators (followed by 3 digits).
    // e.g. "1,000" -> "1000", "1,500.50" -> "1500.50", "1,000,000" -> "1000000"
    text = text.replaceAll(RegExp(r',(?=\d{3})'), '');

    return text;
  }

  static String _convertArabicNumeralsToEnglish(String text) {
    const arabicNumerals = '٠١٢٣٤٥٦٧٨٩';
    const englishNumerals = '0123456789';

    for (int i = 0; i < arabicNumerals.length; i++) {
      text = text.replaceAll(arabicNumerals[i], englishNumerals[i]);
    }
    return text;
  }
}
