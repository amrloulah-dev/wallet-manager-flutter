import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helper.dart';

class TransactionModel {
  final String transactionId;
  final String storeId;
  final String walletId;
  final String transactionType; // 'send' | 'receive' | 'deposit'
  final String? customerPhone;
  final String? customerName;
  final double amount;
  final double commission;
  final double serviceFee; // Fee charged by the network/service
  final String paymentStatus; // 'paid' | 'debt'
  final String? debtId;
  final String? notes;
  final Timestamp transactionDate;
  final Timestamp createdAt;
  final String createdBy;
  final Timestamp? updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final Timestamp? deletedAt;
  final String? deletedBy;

  TransactionModel({
    required this.transactionId,
    required this.storeId,
    required this.walletId,
    required this.transactionType,
    this.customerPhone,
    this.customerName,
    required this.amount,
    this.commission = 0.0,
    this.serviceFee = 0.0,
    this.paymentStatus = 'paid',
    this.debtId,
    this.notes,
    required this.transactionDate,
    required this.createdAt,
    required this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      transactionId: doc.id,
      storeId: data[FirebaseConstants.storeId] ?? '',
      walletId: data[FirebaseConstants.walletId] ?? '',
      transactionType: data['transactionType'] ?? 'send',
      customerPhone: data['customerPhone'],
      customerName: data['customerName'],
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      commission: (data['commission'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (data['serviceFee'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: data['paymentStatus'] ?? 'paid',
      debtId: data['debtId'],
      notes: data[FirebaseConstants.notes],
      transactionDate: data['transactionDate'] ?? Timestamp.now(),
      createdAt: data[FirebaseConstants.createdAt] ?? Timestamp.now(),
      createdBy: data[FirebaseConstants.createdBy] ?? '',
      updatedAt: data[FirebaseConstants.updatedAt],
      updatedBy: data['updatedBy'],
      isDeleted: data['isDeleted'] ?? false,
      deletedAt: data['deletedAt'],
      deletedBy: data['deletedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.storeId: storeId,
      FirebaseConstants.walletId: walletId,
      'transactionType': transactionType,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'amount': amount,
      'commission': commission,
      'serviceFee': serviceFee,
      'paymentStatus': paymentStatus,
      'debtId': debtId,
      FirebaseConstants.notes: notes,
      'transactionDate': transactionDate,
      FirebaseConstants.createdAt: createdAt,
      FirebaseConstants.createdBy: createdBy,
      FirebaseConstants.updatedAt: updatedAt,
      'updatedBy': updatedBy,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
      'deletedBy': deletedBy,
    };
  }

  TransactionModel copyWith({
    String? transactionId,
    String? storeId,
    String? walletId,
    String? transactionType,
    String? customerPhone,
    String? customerName,
    double? amount,
    double? commission,
    double? serviceFee,
    String? paymentStatus,
    String? debtId,
    String? notes,
    Timestamp? transactionDate,
    Timestamp? createdAt,
    String? createdBy,
    Timestamp? updatedAt,
    String? updatedBy,
    bool? isDeleted,
    Timestamp? deletedAt,
    String? deletedBy,
  }) {
    return TransactionModel(
      transactionId: transactionId ?? this.transactionId,
      storeId: storeId ?? this.storeId,
      walletId: walletId ?? this.walletId,
      transactionType: transactionType ?? this.transactionType,
      customerPhone: customerPhone ?? this.customerPhone,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      commission: commission ?? this.commission,
      serviceFee: serviceFee ?? this.serviceFee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      debtId: debtId ?? this.debtId,
      notes: notes ?? this.notes,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }

  // Getters
  bool get isSend => transactionType == 'send';
  bool get isReceive => transactionType == 'receive';
  bool get isDeposit => transactionType == 'deposit';
  bool get isPaid => paymentStatus == 'paid';
  bool get isDebt => paymentStatus == 'debt';
  double get totalAmount =>
      amount + commission; // Original total amount (base + comm)
  String get transactionTypeDisplay =>
      isSend ? 'إرسال' : (isReceive ? 'استقبال' : 'إيداع');
  IconData get transactionTypeIcon => isSend
      ? Icons.arrow_upward
      : (isReceive ? Icons.arrow_downward : Icons.add_card_outlined);
  Color get transactionTypeColor => isSend
      ? AppColors.send
      : (isReceive ? AppColors.receive : AppColors.primary);
  String get paymentStatusDisplay => isPaid ? 'مدفوع' : 'دين';
  bool get canBeModified {
    // Can be modified within 5 minutes of creation
    return DateTime.now().difference(createdAt.toDate()).inMinutes < 5;
  }

  String get formattedDate =>
      DateHelper.formatTimestamp(transactionDate, format: 'dd/MM/yyyy');
  String get formattedTime =>
      DateHelper.formatTimestamp(transactionDate, format: 'hh:mm a');
  String get relativeTime =>
      DateHelper.getRelativeTime(transactionDate.toDate());

  @override
  String toString() {
    return 'TransactionModel(id: $transactionId, type: $transactionType, amount: $amount, serviceFee: $serviceFee, status: $paymentStatus)';
  }
}
