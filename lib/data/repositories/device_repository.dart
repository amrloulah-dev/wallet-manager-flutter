import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/number_parser.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';

class DeviceRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfoPlugin,
  })  : _firestore = firestore ?? sl<FirebaseFirestore>(),
        _auth = auth ?? sl<FirebaseAuth>(),
        _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  /// Retrieves a unique device identifier.
  ///
  /// Strategies:
  /// - Android: Returns `androidInfo.id`.
  /// - iOS: Returns `iosInfo.identifierForVendor`.
  /// - Fallback: Returns a generated UUID (should be persuasive to use standard persistent IDs where possible).
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        return iosInfo.identifierForVendor ?? const Uuid().v4();
      } else {
        // Fallback for other platforms or if platform check fails somehow
        // Note: For web, user agent or specific web implementation would be needed but
        // request focused on Android/iOS checks.
        return const Uuid().v4();
      }
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'DeviceRepository.getDeviceId');
      return const Uuid().v4();
    }
  }

  /// Checks if the device is eligible for a new trial store.
  ///
  /// Returns `true` if the device has created fewer than 2 stores.
  Future<bool> checkDeviceEligibility(String deviceId) async {
    try {
      final docSnapshot = await _firestore
          .collection(FirebaseConstants.deviceRegistrationsCollection)
          .doc(deviceId)
          .get();

      if (!docSnapshot.exists) {
        return true; // No record exists, eligible
      }

      final data = docSnapshot.data();
      if (data == null) return true;

      final trialCount = NumberParser.toInt(data['trialCount']);
      return trialCount < 2;
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'DeviceRepository.checkDeviceEligibility');
      return true;
    }
  }

  /// Registers a new store creation for the device.
  ///
  /// Increments `trialCount` and adds `newStoreId` to `associatedStoreIds`.
  Future<void> registerDeviceUsage(String deviceId, String newStoreId) async {
    final docRef = _firestore
        .collection(FirebaseConstants.deviceRegistrationsCollection)
        .doc(deviceId);

    try {
      await docRef.set({
        'trialCount': FieldValue.increment(1),
        'associatedStoreIds': FieldValue.arrayUnion([newStoreId]),
        'lastTrialDate': FieldValue.serverTimestamp(),
        'ownerUid': _auth.currentUser?.uid,
        FirebaseConstants.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e, stack) {
      AppErrorHandler.handle(e, stackTrace: stack, operation: 'DeviceRepository.registerDeviceUsage');
      rethrow;
    }
  }
}
