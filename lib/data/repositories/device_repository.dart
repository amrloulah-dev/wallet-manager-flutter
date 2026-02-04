import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class DeviceRepository {
  final FirebaseFirestore _firestore;
  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceRepository({
    FirebaseFirestore? firestore,
    DeviceInfoPlugin? deviceInfoPlugin,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
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
    } catch (e) {
      debugPrint('Error getting device ID: $e');
      return const Uuid().v4();
    }
  }

  /// Checks if the device is eligible for a new trial store.
  ///
  /// Returns `true` if the device has created fewer than 2 stores.
  Future<bool> checkDeviceEligibility(String deviceId) async {
    try {
      final docSnapshot = await _firestore
          .collection('device_registrations')
          .doc(deviceId)
          .get();

      if (!docSnapshot.exists) {
        return true; // No record exists, eligible
      }

      final data = docSnapshot.data();
      if (data == null) return true;

      final trialCount = data['trialCount'] as int? ?? 0;
      return trialCount < 2;
    } catch (e) {
      debugPrint('Error checking device eligibility: $e');
      // Fail safe: return true or false based on policy.
      // Returning false might block legitimate users if error is transient,
      // but returning true might allow abuse.
      // Assuming "fail open" for UX, but ideally handle error explicitly.
      return true;
    }
  }

  /// Registers a new store creation for the device.
  ///
  /// Increments `trialCount` and adds `newStoreId` to `associatedStoreIds`.
  Future<void> registerDeviceUsage(String deviceId, String newStoreId) async {
    final docRef = _firestore.collection('device_registrations').doc(deviceId);

    try {
      await docRef.set({
        'trialCount': FieldValue.increment(1),
        'associatedStoreIds': FieldValue.arrayUnion([newStoreId]),
        'lastTrialDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error registering device usage: $e');
      rethrow;
    }
  }
}
