import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Generate and save a batch of license keys to Firestore
  static Future<void> generateAndSaveBatch({int count = 50}) async {
    final firestore = FirebaseFirestore.instance;
    final collection = firestore.collection('license_keys');

    try {
      int remaining = count;
      while (remaining > 0) {
        final batchCount = remaining > 500 ? 500 : remaining;
        final batch = firestore.batch();

        for (int i = 0; i < batchCount; i++) {
          final docRef = collection.doc();
          final key = generateKey();

          batch.set(docRef, {
            'keyId': docRef.id,
            'licenseKey': key,
            'isUsed': false,
            'usedBy': null,
            'usedAt': null,
            'createdAt': FieldValue.serverTimestamp(),
            'expiryMonths': 12,
          });
        }

        await batch.commit();
        remaining -= batchCount;
      }
    } catch (e) {
      rethrow;
    }
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
