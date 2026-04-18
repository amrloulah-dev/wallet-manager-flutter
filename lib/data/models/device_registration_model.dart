import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceRegistrationModel {
  final String deviceId; // Local generated UUID
  final String deviceModel;
  final String osVersion;
  final Timestamp firstSeenAt;
  final Timestamp lastSeenAt;
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
      firstSeenAt: data['firstSeenAt'] ?? Timestamp.now(),
      lastSeenAt: data['lastSeenAt'] ?? Timestamp.now(),
      ownerUid: data['ownerUid'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'firstSeenAt': firstSeenAt,
      'lastSeenAt': lastSeenAt,
      'ownerUid': ownerUid,
    };
  }

  DeviceRegistrationModel copyWith({
    String? deviceId,
    String? deviceModel,
    String? osVersion,
    Timestamp? firstSeenAt,
    Timestamp? lastSeenAt,
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
