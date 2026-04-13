import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceRegistryModel {
  final String deviceId; // Local generated UUID
  final String deviceModel;
  final String osVersion;
  final Timestamp firstSeenAt;
  final Timestamp lastSeenAt;

  DeviceRegistryModel({
    required this.deviceId,
    required this.deviceModel,
    required this.osVersion,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  factory DeviceRegistryModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('DeviceRegistry document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;
    return DeviceRegistryModel(
      deviceId: doc.id,
      deviceModel: data['deviceModel'] ?? '',
      osVersion: data['osVersion'] ?? '',
      firstSeenAt: data['firstSeenAt'] ?? Timestamp.now(),
      lastSeenAt: data['lastSeenAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'firstSeenAt': firstSeenAt,
      'lastSeenAt': lastSeenAt,
    };
  }

  DeviceRegistryModel copyWith({
    String? deviceId,
    String? deviceModel,
    String? osVersion,
    Timestamp? firstSeenAt,
    Timestamp? lastSeenAt,
  }) {
    return DeviceRegistryModel(
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
