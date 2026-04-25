import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/license_key_model.dart';
import '../models/store_model.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/license_key_generator.dart';

class LicenseKeyRepository {
  late final FirebaseFirestore _firestore;
  late final CollectionReference _keysCollection;

  LicenseKeyRepository({FirebaseFirestore? firestore}) {
    _firestore = firestore ?? FirebaseFirestore.instance;
    _keysCollection = _firestore.collection('license_keys');
  }

  /// Verify if a license key exists and fetch its data
  Future<LicenseKeyModel?> verifyLicenseKey(String licenseKey) async {
    try {
      final trimmedKey = licenseKey.trim().toUpperCase();

      // Now try the actual query
      final querySnapshot = await _keysCollection
          .where('licenseKey', isEqualTo: trimmedKey)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final keyDoc = querySnapshot.docs.first;

      return LicenseKeyModel.fromFirestore(keyDoc);
    } catch (e) {
      throw ServerException('حدث خطأ أثناء التحقق من المفتاح');
    }
  }

  /// Activate a specific license key and mark it as used using a transaction
  Future<void> activateLicenseKey({
    required String keyId,
    required String storeId,
  }) async {
    final keyRef = _keysCollection.doc(keyId);
    final storeRef = _firestore.collection('stores').doc(storeId);

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Fetch Key Data inside transaction
        final keySnapshot = await transaction.get(keyRef);
        if (!keySnapshot.exists) {
          throw ServerException('مفتاح الترخيص غير موجود');
        }

        final keyData = keySnapshot.data() as Map<String, dynamic>;

        // Double check usage status
        if (keyData['isUsed'] == true) {
          throw ServerException('هذا المفتاح مستخدم بالفعل');
        }

        final expiryMonths = keyData['expiryMonths'] ?? 12; // Default to 1 year

        // Calculate new expiry date
        // We add days: 30 * months as a standard approximation or use DateTime logic
        final DateTime now = DateTime.now();
        // Careful with month addition in Dart, simplified approach:
        final DateTime newExpiryDate =
            now.add(Duration(days: expiryMonths * 30));

        // 2. Update License Key Doc
        transaction.update(keyRef, {
          'isUsed': true,
          'usedBy': storeId,
          'usedAt': FieldValue.serverTimestamp(),
        });

        // 3. Update Store Doc
        transaction.update(storeRef, {
          'subscription.planId': 'premium',
          'subscription.status': SubscriptionStatus.active.name,
          'subscription.endDate': Timestamp.fromDate(newExpiryDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e is ServerException) rethrow; // Pass up our custom exceptions
      throw ServerException('فشل في تفعيل الاشتراك: $e');
    }
  }

  /// Generate and save a batch of license keys to Firestore
  Future<void> generateAndSaveBatch({int count = 50}) async {
    try {
      int remaining = count;
      while (remaining > 0) {
        final batchCount = remaining > 500 ? 500 : remaining;
        final batch = _firestore.batch();

        for (int i = 0; i < batchCount; i++) {
          final docRef = _keysCollection.doc();
          final key = LicenseKeyGenerator.generateKey();

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
      throw ServerException('Failed to generate license keys: $e');
    }
  }

  /// Check if a given license key exists and is available for use
  Future<bool> isKeyAvailable(String licenseKey) async {
    try {
      final keyData = await verifyLicenseKey(licenseKey);
      if (keyData == null) return false;
      if (keyData.isUsed == true) return false;
      return true;
    } catch (e) {
      return false;
    }
  }
}
