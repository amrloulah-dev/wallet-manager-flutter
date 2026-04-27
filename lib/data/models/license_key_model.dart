import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/number_parser.dart';
import '../../core/errors/app_exceptions.dart';

class LicenseKeyModel {
  final String keyId;
  final String licenseKey;
  final bool isUsed;
  final String? usedBy;
  final DateTime? usedAt;
  final DateTime createdAt;
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
      usedAt: (data['usedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? 
        (throw NotFoundException('LicenseKey document missing required field: createdAt')),
      expiryMonths: NumberParser.toInt(data['expiryMonths'], 12),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'keyId': keyId,
      'licenseKey': licenseKey,
      'isUsed': isUsed,
      'usedBy': usedBy,
      'usedAt': usedAt != null ? Timestamp.fromDate(usedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiryMonths': expiryMonths,
    };
  }
}
