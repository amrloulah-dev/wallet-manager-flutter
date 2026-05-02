import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/license_key_model.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/license_key_generator.dart';
import '../../core/enums/subscription_enums.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/errors/app_error_handler.dart';

class LicenseKeyRepository {
  final FirebaseFirestore _firestore;
  final CollectionReference _keysCollection;

  LicenseKeyRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseFirestore>(),
        _keysCollection = (firestore ?? sl<FirebaseFirestore>())
            .collection(FirebaseConstants.licenseKeysCollection);

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
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'LicenseKeyRepository.verifyLicenseKey');
      throw ServerException('حدث خطأ أثناء التحقق من المفتاح: $e');
    }
  }

  /// Activate a specific license key and mark it as used using a transaction
  Future<void> activateLicenseKey({
    required String keyId,
    required String storeId,
  }) async {
    final keyRef = _keysCollection.doc(keyId);
    final storeRef = _firestore.collection(FirebaseConstants.storesCollection).doc(storeId);

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

        // 1. Calculate new expiry date with precise month logic
        final DateTime now = DateTime.now();
        final DateTime newExpiryDate = DateTime(
          now.year,
          now.month + (expiryMonths as int),
          now.day,
          now.hour,
          now.minute,
        );

        // 2. Update License Key Doc
        transaction.update(keyRef, {
          'isUsed': true,
          'usedBy': storeId,
          'usedAt': FieldValue.serverTimestamp(),
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });

        // 3. Update Store Doc
        transaction.update(storeRef, {
          'subscription.planId': SubscriptionPlan.proYearly.name, // ENUM refactor
          'subscription.status': SubscriptionStatus.active.name, // ENUM refactor
          'subscription.endDate': Timestamp.fromDate(newExpiryDate),
          FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
        });
      });
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'LicenseKeyRepository.activateLicenseKey');
      if (e is ServerException) rethrow; // Pass up our custom exceptions
      throw ServerException('فشل في تفعيل الاشتراك: $e');
    }
  }

  /// Generate and save a batch of license keys to Firestore
  Future<void> generateAndSaveBatch({int count = 50}) async {
    try {
      int remaining = count;
      while (remaining > 0) {
        final batchCount = remaining > 450 ? 450 : remaining;
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
            FirebaseConstants.createdAt: FieldValue.serverTimestamp(),
            'expiryMonths': 12,
          });
        }

        await batch.commit();
        remaining -= batchCount;
      }
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'LicenseKeyRepository.generateAndSaveBatch');
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
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'LicenseKeyRepository.isKeyAvailable');
      return false;
    }
  }
}
