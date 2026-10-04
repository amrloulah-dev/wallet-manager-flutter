import 'dart:math';

class LicenseKeyGenerator {
  // Prevent instantiation
  LicenseKeyGenerator._();

  /// Generate a random license key
  static String generateKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // exclude I, L, O, 0, 1
    final random = Random.secure();

    String randomPart(int length) => List.generate(
          length,
          (_) => chars[random.nextInt(chars.length)],
        ).join();

    final part1 = randomPart(4);
    final part2 = randomPart(4);

    return 'WALLET-2025-$part1-$part2';
  }

  /// Generate a list of random keys without saving
  static Future<List<String>> generateKeysList(int count) async {
    final keys = <String>[];
    for (int i = 0; i < count; i++) {
      keys.add(generateKey());
    }
    return keys;
  }
}
