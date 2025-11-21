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

  /// Activate a specific license key and mark it as used
  Future<void> activateLicenseKey({
    required String keyId,
    required String storeId,
  }) async {
    try {
      await _keysCollection.doc(keyId).update({
        'isUsed': true,
        'usedBy': storeId,
        'usedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ServerException('حدث خطأ أثناء تفعيل المفتاح');
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
