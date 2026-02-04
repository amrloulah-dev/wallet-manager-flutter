import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceUsageModel {
  final String deviceId;
  final int trialCount;
  final Timestamp lastTrialDate;
  final List<String> associatedStoreIds;

  DeviceUsageModel({
    required this.deviceId,
    required this.trialCount,
    required this.lastTrialDate,
    required this.associatedStoreIds,
  });

  /// Creates a DeviceUsageModel from a Firestore document snapshot.
  factory DeviceUsageModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('Device document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;

    return DeviceUsageModel(
      deviceId: doc.id,
      trialCount: data['trialCount'] ?? 0,
      lastTrialDate: data['lastTrialDate'] ?? Timestamp.now(),
      associatedStoreIds: List<String>.from(data['associatedStoreIds'] ?? []),
    );
  }

  /// Converts the DeviceUsageModel instance to a map for Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'trialCount': trialCount,
      'lastTrialDate': lastTrialDate,
      'associatedStoreIds': associatedStoreIds,
    };
  }

  DeviceUsageModel copyWith({
    String? deviceId,
    int? trialCount,
    Timestamp? lastTrialDate,
    List<String>? associatedStoreIds,
  }) {
    return DeviceUsageModel(
      deviceId: deviceId ?? this.deviceId,
      trialCount: trialCount ?? this.trialCount,
      lastTrialDate: lastTrialDate ?? this.lastTrialDate,
      associatedStoreIds: associatedStoreIds ?? this.associatedStoreIds,
    );
  }

  @override
  String toString() {
    return 'DeviceUsageModel(deviceId: $deviceId, trialCount: $trialCount, associatedStoreIds: $associatedStoreIds)';
  }
}
