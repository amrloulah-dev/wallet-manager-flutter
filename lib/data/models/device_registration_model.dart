import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/errors/app_exceptions.dart';

class DeviceRegistrationModel {
  final String deviceId; // Local generated UUID
  final String deviceModel;
  final String osVersion;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final String? ownerUid;

  DeviceRegistrationModel({
    required this.deviceId,
    required this.deviceModel,
    required this.osVersion,
    required this.firstSeenAt,
    required this.lastSeenAt,
    this.ownerUid,
  });

  factory DeviceRegistrationModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('DeviceRegistration document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;
    return DeviceRegistrationModel(
      deviceId: doc.id,
      deviceModel: data['deviceModel'] ?? '',
      osVersion: data['osVersion'] ?? '',
      firstSeenAt: (data['firstSeenAt'] as Timestamp?)?.toDate() ?? 
        (throw NotFoundException('DeviceRegistration document missing required field: firstSeenAt')),
      lastSeenAt: (data['lastSeenAt'] as Timestamp?)?.toDate() ?? 
        (throw NotFoundException('DeviceRegistration document missing required field: lastSeenAt')),
      ownerUid: data['ownerUid'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'firstSeenAt': Timestamp.fromDate(firstSeenAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
      'ownerUid': ownerUid,
    };
  }

  DeviceRegistrationModel copyWith({
    String? deviceId,
    String? deviceModel,
    String? osVersion,
    DateTime? firstSeenAt,
    DateTime? lastSeenAt,
    String? ownerUid,
  }) {
    return DeviceRegistrationModel(
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      ownerUid: ownerUid ?? this.ownerUid,
    );
  }
}
