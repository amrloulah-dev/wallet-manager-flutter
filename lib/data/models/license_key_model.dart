import 'package:cloud_firestore/cloud_firestore.dart';

class LicenseKeyModel {
  final String keyId;
  final String licenseKey;
  final bool isUsed;
  final String? usedBy;
  final Timestamp? usedAt;
  final Timestamp createdAt;
  final int expiryMonths;

  LicenseKeyModel({
    required this.keyId,
    required this.licenseKey,
    required this.isUsed,
    this.usedBy,
    this.usedAt,
    required this.createdAt,
    required this.expiryMonths,
  });

  factory LicenseKeyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LicenseKeyModel(
      keyId: doc.id,
      licenseKey: data['licenseKey'] ?? '',
      isUsed: data['isUsed'] ?? false,
      usedBy: data['usedBy'],
      usedAt: data['usedAt'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      expiryMonths: data['expiryMonths'] ?? 12,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'keyId': keyId,
      'licenseKey': licenseKey,
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedAt': usedAt,
      'createdAt': createdAt,
      'expiryMonths': expiryMonths,
    };
  }
}
