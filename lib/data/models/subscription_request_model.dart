import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/number_parser.dart';
import '../../core/errors/app_exceptions.dart';

class SubscriptionRequestModel {
  final String id;
  final String storeId;
  final String planId; // 'pro_yearly', 'lifetime', etc.
  final double amount;
  final String paymentMethod; // 'vodafone_cash', 'instapay'
  final String receiptNumber; // Transaction ID
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? processedAt;

  SubscriptionRequestModel({
    required this.id,
    required this.storeId,
    required this.planId,
    required this.amount,
    required this.paymentMethod,
    required this.receiptNumber,
    this.status = 'pending',
    this.rejectionReason,
    required this.createdAt,
    this.processedAt,
  });

  factory SubscriptionRequestModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('SubscriptionRequest document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;

    final amount = NumberParser.toDouble(data['amount']);
    if (!amount.isFinite || amount < 0) {
      throw DomainException('Invalid subscription amount: $amount');
    }

    return SubscriptionRequestModel(
      id: doc.id,
      storeId: data['storeId'] ?? '',
      planId: data['planId'] ?? '',
      amount: amount,
      paymentMethod: data['paymentMethod'] ?? '',
      receiptNumber: data['receiptNumber'] ?? '',
      status: data['status'] ?? 'pending',
      rejectionReason: data['rejectionReason'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (throw NotFoundException(
              'SubscriptionRequest document missing required field: createdAt')),
      processedAt: (data['processedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'storeId': storeId,
      'planId': planId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'receiptNumber': receiptNumber,
      'status': status,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt':
          processedAt != null ? Timestamp.fromDate(processedAt!) : null,
    };
  }

  SubscriptionRequestModel copyWith({
    String? id,
    String? storeId,
    String? planId,
    double? amount,
    String? paymentMethod,
    String? receiptNumber,
    String? status,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? processedAt,
  }) {
    return SubscriptionRequestModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      planId: planId ?? this.planId,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}
