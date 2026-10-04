import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/constants/firebase_constants.dart';
import '../models/system_configs_model.dart';

class SystemConfigRepository {
  final FirebaseFirestore _firestore;

  SystemConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? sl<FirebaseFirestore>();

  Future<SystemConfigsModel> getConfigs() async {
    final doc = await _firestore
        .collection(FirebaseConstants.systemConfigsCollection)
        .doc(FirebaseConstants.defaultConfigDoc)
        .get();
    return SystemConfigsModel.fromFirestore(doc);
  }

  Stream<SystemConfigsModel> watchConfigs() {
    return _firestore
        .collection(FirebaseConstants.systemConfigsCollection)
        .doc(FirebaseConstants.defaultConfigDoc)
        .snapshots()
        .map((doc) => SystemConfigsModel.fromFirestore(doc));
  }
}
