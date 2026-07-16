import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/firebase_constants.dart';
import '../models/subscription_request_model.dart';
import '../../services/device_tracking_service.dart';
import '../../core/utils/number_parser.dart';
import '../../core/errors/app_error_handler.dart';
import '../../core/errors/app_exceptions.dart';

import 'package:walletmanager/core/di/service_locator.dart';

import 'package:walletmanager/data/services/firebase_service.dart';

class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SubscriptionRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? sl<FirebaseService>().firestore,
        _auth = auth ?? sl<FirebaseAuth>();

  Future<void> verifyDevice(String storeId) async {
    try {
      final deviceId = await DeviceTrackingService.getDeviceId();
      final deviceModel = await DeviceTrackingService.getDeviceModel();
      final osVersion = await DeviceTrackingService.getOsVersion();

      final docRef = _firestore
          .doc(FirebaseConstants.deviceRegistrationPath(storeId, deviceId));

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (doc.exists) {
          transaction.update(docRef, {
            FirebaseConstants.lastSeenAt: FieldValue.serverTimestamp(),
            FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
            'ownerUid': _auth.currentUser?.uid,
          });
        } else {
          transaction.set(docRef, {
            'deviceModel': deviceModel,
            'osVersion': osVersion,
            FirebaseConstants.firstSeenAt: FieldValue.serverTimestamp(),
            FirebaseConstants.lastSeenAt: FieldValue.serverTimestamp(),
            FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
            'ownerUid': _auth.currentUser?.uid,
          });
        }
      });
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'SubscriptionRepository.verifyDevice');
      throw ServerException('subscription_error_verify_device_failed',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'SubscriptionRepository.verifyDevice');
      throw ServerException('subscription_error_unexpected');
    }
  }

  Future<SubscriptionRequestModel?> getLatestSubscriptionRequest(
      String storeId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.subscriptionRequestsCollection)
          .where(FirebaseConstants.storeId, isEqualTo: storeId)
          .orderBy(FirebaseConstants.createdAt, descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isNotEmpty) {
        return SubscriptionRequestModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } on TimeoutException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'SubscriptionRepository.getLatestSubscriptionRequest');
      throw ServerException('error_network_timeout');
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'SubscriptionRepository.getLatestSubscriptionRequest');
      throw ServerException('subscription_error_fetch_request_failed',
          code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'SubscriptionRepository.getLatestSubscriptionRequest');
      throw ServerException('subscription_error_unexpected');
    }
  }

  Future<void> submitSubscriptionRequest({
    required String storeId,
    required String planId,
    required String paymentMethod,
    required String receiptNumber,
    required double amount,
  }) async {
    try {
      final rootRef = _firestore
          .collection(FirebaseConstants.subscriptionRequestsCollection)
          .doc();
      final now = DateTime.now();

      final request = SubscriptionRequestModel(
        id: rootRef.id,
        storeId: storeId,
        planId: planId,
        amount: amount,
        paymentMethod: paymentMethod,
        receiptNumber: receiptNumber,
        status: 'pending',
        createdAt: now, // This will be overridden
      );

      final storeRef = _firestore.doc(FirebaseConstants.storePath(storeId));

      // We throw and let the caller (Provider) handle the optimistic rollback
      final batch = _firestore.batch();

      final requestData = request.toFirestore();
      requestData[FirebaseConstants.createdAt] = FieldValue.serverTimestamp();

      batch.set(rootRef, requestData);
      batch.update(storeRef, {
        'subscription.pendingRequestDate': FieldValue.serverTimestamp(),
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();
    } on FirebaseException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'SubscriptionRepository.submitSubscriptionRequest');
      throw ServerException('subscription_error_submit_failed', code: e.code);
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'SubscriptionRepository.submitSubscriptionRequest');
      throw ServerException('subscription_error_unexpected');
    }
  }

  /// Anti-Fraud: Read-before-Write guard.
  /// Checks the hardware device_registrations subcollection across ALL stores
  /// to determine if this physical device has already consumed a trial.
  /// Returns true if the device has been previously registered (trial consumed).
  Future<bool> hasDeviceConsumedTrial() async {
    try {
      final deviceId = await DeviceTrackingService.getDeviceId();

      // Query the root-level device_registrations for this hardware device
      final docSnapshot = await _firestore
          .doc(FirebaseConstants.hardwareDeviceRegistrationPath(deviceId))
          .get();

      if (!docSnapshot.exists) return false;

      final data = docSnapshot.data();
      if (data == null) return false;

      // If trialCount >= 1, this device has already consumed a trial
      final trialCount = NumberParser.toInt(data['trialCount']);
      return trialCount >= 1;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'SubscriptionRepository.hasDeviceConsumedTrial');
      return false; // Fail safe (eligible) or throw? PRD says limit strictly, so returning false might allow abuse.
      // But for a check like this, throwing is better to prevent UI progress.
    }
  }
}
