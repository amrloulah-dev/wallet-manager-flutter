import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/number_parser.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class DeviceRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final DeviceInfoPlugin _deviceInfoPlugin;
  final LocalStorageService _localStorageService;

  DeviceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    DeviceInfoPlugin? deviceInfoPlugin,
    LocalStorageService? localStorageService,
  })  : _firestore = firestore ?? sl<FirebaseFirestore>(),
        _auth = auth ?? sl<FirebaseAuth>(),
        _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin(),
        _localStorageService = localStorageService ?? LocalStorageService();

  /// Retrieves a unique device identifier.
  ///
  /// Strategies:
  /// 1. Check LocalStorageService for a previously saved persistent UUID.
  /// 2. If not found, attempt to get platform-specific ID (Android/iOS).
  /// 3. If platform check fails, generate a new UUID, save it, and return.
  Future<String> getDeviceId() async {
    try {
      // 1. Try local storage first (Surgical Strike Fix)
      final savedId = _localStorageService.persistentDeviceId;
      if (savedId != null && savedId.isNotEmpty) {
        return savedId;
      }

      String? deviceId;

      // 2. Platform Specific Logic
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        deviceId = iosInfo.identifierForVendor;
      }

      // 3. Fallback & Persistence
      if (deviceId == null || deviceId.isEmpty || deviceId == 'unknown') {
        deviceId = const Uuid().v4();
        await _localStorageService.savePersistentDeviceId(deviceId);
      } else {
        // Even if we got a platform ID, save it to local storage for future speed/consistency
        await _localStorageService.savePersistentDeviceId(deviceId);
      }

      return deviceId;
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DeviceRepository.getDeviceId');

      // Last resort fallback
      final fallbackId =
          _localStorageService.persistentDeviceId ?? const Uuid().v4();
      if (_localStorageService.persistentDeviceId == null) {
        await _localStorageService.savePersistentDeviceId(fallbackId);
      }
      return fallbackId;
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
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'DeviceRepository.checkDeviceEligibility');
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
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'DeviceRepository.registerDeviceUsage');
      rethrow;
    }
  }
}
