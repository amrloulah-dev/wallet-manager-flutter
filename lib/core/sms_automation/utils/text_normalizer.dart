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

    // 2. Clean Numbers
    // Convert Arabic/Eastern numerals to English/Western numerals
    text = _convertArabicNumeralsToEnglish(text);

    // Remove commas from numbers is tricky if we do it globally,
    // but usually 1,000 becomes 1000.
    // We strictly want to remove commas that are part of numbers.
    // However, the requirement says "Remove commas , from numbers".
    // A simple approach is to remove all commas if they are between digits,
    // or just remove all commas if the text structure allows.
    // Given SMS context, removing commas is generally safe for amount parsing.
    text = text.replaceAll(',', '');

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
