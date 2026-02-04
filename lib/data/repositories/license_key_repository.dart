import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/license_key_model.dart';
import '../../core/errors/app_exceptions.dart';

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
        final licenseKeyString = keyData['licenseKey'];

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
          'licenseKeyId': keyId,
          'activeLicenseKey': licenseKeyString,
          'license.licenseKey': licenseKeyString,
          'license.licenseType': 'premium',
          'license.status': 'active',
          'license.expiryDate': Timestamp.fromDate(newExpiryDate),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      if (e is ServerException) rethrow; // Pass up our custom exceptions
      throw ServerException('فشل في تفعيل الاشتراك: $e');
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
