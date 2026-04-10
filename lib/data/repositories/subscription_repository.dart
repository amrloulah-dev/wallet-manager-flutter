import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_registry_model.dart';
import '../models/subscription_request_model.dart';
import '../../services/device_tracking_service.dart';

class SubscriptionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> verifyDevice(String storeId) async {
    final deviceId = await DeviceTrackingService.getDeviceId();
    final deviceModel = await DeviceTrackingService.getDeviceModel();
    final osVersion = await DeviceTrackingService.getOsVersion();
    
    final docRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('device_registry')
        .doc(deviceId);
    
    // T047: Explicitly perform client-side Firestore query against device_registry
    // For this MVP phase, we use direct client-side reads rather than server-side Cloud Functions.
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.update({
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } else {
      final registryModel = DeviceRegistryModel(
        deviceId: deviceId,
        deviceModel: deviceModel,
        osVersion: osVersion,
        firstSeenAt: Timestamp.now(),
        lastSeenAt: Timestamp.now(),
      );
      
      await docRef.set(registryModel.toFirestore());
    }
  }

  Future<SubscriptionRequestModel?> getLatestSubscriptionRequest(String storeId) async {
    final snapshot = await _firestore
        .collection('subscription_requests')
        .where('storeId', isEqualTo: storeId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
        
    if (snapshot.docs.isNotEmpty) {
      return SubscriptionRequestModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  double _deduceAmount(String planId) {
    if (planId == 'lifetime') return 2500.0;
    if (planId == 'pro_yearly') return 1200.0;
    return 0.0; // Assume free/trial or fallback
  }

  Future<void> submitSubscriptionRequest({
    required String storeId,
    required String planId,
    required String paymentMethod,
    required String receiptNumber,
  }) async {
    final rootRef = _firestore.collection('subscription_requests').doc();
    final now = Timestamp.now();
    // T045: Implicitly deduce amount using tierName locally
    final double deducedAmount = _deduceAmount(planId);
    
    final request = SubscriptionRequestModel(
      id: rootRef.id,
      storeId: storeId,
      planId: planId,
      amount: deducedAmount,
      paymentMethod: paymentMethod,
      receiptNumber: receiptNumber,
      status: 'pending',
      createdAt: now,
    );
    
    final storeRef = _firestore.collection('stores').doc(storeId);
    
    // We throw and let the caller (Provider) handle the optimistic rollback
    final batch = _firestore.batch();
    batch.set(rootRef, request.toFirestore());
    batch.update(storeRef, {
      'subscription.pendingRequestDate': now,
    });
    await batch.commit();
  }
}

