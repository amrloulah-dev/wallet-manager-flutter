import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../core/utils/number_parser.dart';

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
  final DateTime transactionDate;
  final DateTime createdAt;
  final String createdBy;
  final String? createdById;
  final String? createdByName;
  final String? creatorRole;
  final DateTime? updatedAt;
  final String? updatedBy;
  final bool isDeleted;
  final DateTime? deletedAt;
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
    this.createdById,
    this.createdByName,
    this.creatorRole,
    this.updatedAt,
    this.updatedBy,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
  });

  factory TransactionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    final transactionDate = (data['transactionDate'] as Timestamp?)?.toDate();
    if (transactionDate == null) {
      throw const FormatException('Missing or invalid transactionDate in TransactionModel');
    }
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    if (createdAt == null) {
      throw const FormatException('Missing or invalid createdAt in TransactionModel');
    }

    return TransactionModel(
      transactionId: doc.id,
      storeId: data[FirebaseConstants.storeId] ?? '',
      walletId: data[FirebaseConstants.walletId] ?? '',
      transactionType: data['transactionType'] ?? 'send',
      customerPhone: data['customerPhone'],
      customerName: data['customerName'],
      amount: NumberParser.toDouble(data['amount']),
      commission: NumberParser.toDouble(data['commission']),
      serviceFee: NumberParser.toDouble(data['serviceFee']),
      paymentStatus: data['paymentStatus'] ?? 'paid',
      debtId: data['debtId'],
      notes: data[FirebaseConstants.notes],
      transactionDate: transactionDate,
      createdAt: createdAt,
      createdBy: data[FirebaseConstants.createdBy] ?? '',
      createdById: data['createdById'],
      createdByName: data['createdByName'],
      creatorRole: data['creatorRole'],
      updatedAt: (data[FirebaseConstants.updatedAt] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
      isDeleted: data['isDeleted'] ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
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
      'transactionDate': Timestamp.fromDate(transactionDate),
      FirebaseConstants.createdAt: Timestamp.fromDate(createdAt),
      FirebaseConstants.createdBy: createdBy,
      'createdById': createdById,
      'createdByName': createdByName,
      'creatorRole': creatorRole,
      FirebaseConstants.updatedAt: updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'updatedBy': updatedBy,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
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
    DateTime? transactionDate,
    DateTime? createdAt,
    String? createdBy,
    String? createdById,
    String? createdByName,
    String? creatorRole,
    DateTime? updatedAt,
    String? updatedBy,
    bool? isDeleted,
    DateTime? deletedAt,
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
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      creatorRole: creatorRole ?? this.creatorRole,
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
  
  String getTransactionTypeDisplay(AppLocalizations l10n) {
    if (isSend) return l10n.send;
    if (isReceive) return l10n.receive;
    if (isDeposit) return l10n.deposit;
    return transactionType;
  }

  IconData get transactionTypeIcon => isSend
      ? Icons.arrow_upward
      : (isReceive ? Icons.arrow_downward : Icons.add_card_outlined);
  Color get transactionTypeColor => isSend
      ? AppColors.send
      : (isReceive ? AppColors.receive : AppColors.primary);

  String getPaymentStatusDisplay(AppLocalizations l10n) {
    return isPaid ? l10n.paid : l10n.debt;
  }

  bool get canBeModified {
    // Can be modified within 5 minutes of creation
    return DateTime.now().difference(createdAt).inMinutes < 5;
  }

  String get formattedDate =>
      DateHelper.formatDateTime(transactionDate, format: 'dd/MM/yyyy');
  String get formattedTime =>
      DateHelper.formatDateTime(transactionDate, format: 'hh:mm a');

  String getRelativeTime(AppLocalizations l10n) =>
      DateHelper.getRelativeTime(transactionDate, l10n: l10n);

  @override
  String toString() {
    return 'TransactionModel(id: $transactionId, type: $transactionType, amount: $amount, serviceFee: $serviceFee, status: $paymentStatus)';
  }
}
