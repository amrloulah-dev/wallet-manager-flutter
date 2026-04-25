import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/device_registration_model.dart';
import '../models/subscription_request_model.dart';
import '../../services/device_tracking_service.dart';
import '../../core/utils/number_parser.dart';

import 'package:walletmanager/core/di/service_locator.dart';

class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SubscriptionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? sl<FirebaseFirestore>(),
        _auth = auth ?? sl<FirebaseAuth>();

  Future<void> verifyDevice(String storeId) async {
    final deviceId = await DeviceTrackingService.getDeviceId();
    final deviceModel = await DeviceTrackingService.getDeviceModel();
    final osVersion = await DeviceTrackingService.getOsVersion();
    
    final docRef = _firestore
        .collection('stores')
        .doc(storeId)
        .collection('device_registrations')
        .doc(deviceId);
    
    // T047: Explicitly perform client-side Firestore query against device_registrations
    // For this MVP phase, we use direct client-side reads rather than server-side Cloud Functions.
    final doc = await docRef.get();
    
    if (doc.exists) {
      await docRef.update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'ownerUid': _auth.currentUser?.uid,
      });
    } else {
      final registrationModel = DeviceRegistrationModel(
        deviceId: deviceId,
        deviceModel: deviceModel,
        osVersion: osVersion,
        firstSeenAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
        ownerUid: _auth.currentUser?.uid,
      );
      
      await docRef.set(registrationModel.toFirestore());
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
    final now = DateTime.now();
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
      'subscription.pendingRequestDate': Timestamp.fromDate(now),
    });
    await batch.commit();
  }
  /// Anti-Fraud: Read-before-Write guard.
  /// Checks the hardware device_registrations subcollection across ALL stores
  /// to determine if this physical device has already consumed a trial.
  /// Returns true if the device has been previously registered (trial consumed).
  Future<bool> hasDeviceConsumedTrial() async {
    final deviceId = await DeviceTrackingService.getDeviceId();
    
    // Query the root-level device_registrations for this hardware device
    final docSnapshot = await _firestore
        .collection('device_registrations')
        .doc(deviceId)
        .get();
    
    if (!docSnapshot.exists) return false;
    
    final data = docSnapshot.data();
    if (data == null) return false;
    
    // If trialCount >= 1, this device has already consumed a trial
    final trialCount = NumberParser.toInt(data['trialCount']);
    return trialCount >= 1;
  }
}
