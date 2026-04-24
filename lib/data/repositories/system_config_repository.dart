import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import '../models/system_configs_model.dart';

class SystemConfigRepository {
  final FirebaseFirestore _firestore = sl<FirebaseFirestore>();

  Future<SystemConfigsModel> getConfigs() async {
    final doc = await _firestore.collection('system_configs').doc('default').get();
    return SystemConfigsModel.fromFirestore(doc);
  }

  Stream<SystemConfigsModel> watchConfigs() {
    return _firestore
        .collection('system_configs')
        .doc('default')
        .snapshots()
        .map((doc) => SystemConfigsModel.fromFirestore(doc));
  }
}
