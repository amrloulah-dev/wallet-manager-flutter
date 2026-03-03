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

    // 4. Clean Thousands Separators
    // Remove commas ONLY if they act as a thousands separator
    // (followed by exactly 3 digits). This preserves decimal numbers like 100,50.
    // The lookahead (?=\d{3}(?!\d)) ensures the comma is followed by exactly 3 digits.
    text = text.replaceAll(RegExp(r',(?=\d{3}(?!\d))'), '');

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
