import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/utils/date_helper.dart';
import '../../core/theme/app_colors.dart';

class DebtModel {
  // Identity
  final String debtId;
  final String storeId;

  // Customer Info
  final String customerName;
  final String customerPhone;

  // Debt Details
  final String debtType;          // 'transaction' | 'store_sale'
  final double amountDue;         // المبلغ المستحق
  final String? notes;

  // Status
  final String debtStatus;        // 'open' | 'paid'

  // Dates
  final Timestamp debtDate;       // تاريخ إنشاء الدين
  final Timestamp? paidDate;      // تاريخ التسديد (null if open)

  // Tracking
  final String createdBy;         // userId who created
  final Timestamp createdAt;
  final String? markedPaidBy;     // userId who marked as paid
  final Timestamp? updatedAt;
  final String? lastUpdatedBy;

  final String customerNameNormalized;

  DebtModel({
    required this.debtId,
    required this.storeId,
    required this.customerName,
    required this.customerPhone,
    required this.debtType,
    required this.amountDue,
    this.notes,
    this.debtStatus = 'open',
    required this.debtDate,
    this.paidDate,
    required this.createdBy,
    required this.createdAt,
    this.markedPaidBy,
    this.updatedAt,
    this.lastUpdatedBy,
  }) : customerNameNormalized = customerName.trim().toLowerCase();

  factory DebtModel.fromFirestore(DocumentSnapshot doc) {
    if (!doc.exists) {
      throw Exception('Debt document does not exist!');
    }
    final data = doc.data() as Map<String, dynamic>;

    return DebtModel(
      debtId: doc.id,
      storeId: data[FirebaseConstants.storeId] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      debtType: data['debtType'] ?? 'store_sale',
      amountDue: (data['amountDue'] as num?)?.toDouble() ?? 0.0,
      notes: data[FirebaseConstants.notes],
      debtStatus: data['debtStatus'] ?? 'open',
      debtDate: data['debtDate'] ?? Timestamp.now(),
      paidDate: data['paidDate'],
      createdBy: data[FirebaseConstants.createdBy] ?? '',
      createdAt: data[FirebaseConstants.createdAt] ?? Timestamp.now(),
      markedPaidBy: data['markedPaidBy'],
      updatedAt: data['updatedAt'],
      lastUpdatedBy: data['lastUpdatedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.storeId: storeId,
      'customerName': customerName,
      'customerNameNormalized': customerNameNormalized,
      'customerPhone': customerPhone,
      'debtType': debtType,
      'amountDue': amountDue,
      FirebaseConstants.notes: notes,
      'debtStatus': debtStatus,
      'debtDate': debtDate,
      'paidDate': paidDate,
      FirebaseConstants.createdBy: createdBy,
      FirebaseConstants.createdAt: createdAt,
      'markedPaidBy': markedPaidBy,
      'updatedAt': updatedAt,
      'lastUpdatedBy': lastUpdatedBy,
    };
  }

  DebtModel copyWith({
    String? debtId,
    String? storeId,
    String? customerName,
    String? customerPhone,
    String? debtType,
    double? amountDue,
    String? notes,
    String? debtStatus,
    Timestamp? debtDate,
    Timestamp? paidDate,
    String? createdBy,
    Timestamp? createdAt,
    String? markedPaidBy,
    Timestamp? updatedAt,
    String? lastUpdatedBy,
  }) {
    return DebtModel(
      debtId: debtId ?? this.debtId,
      storeId: storeId ?? this.storeId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      debtType: debtType ?? this.debtType,
      amountDue: amountDue ?? this.amountDue,
      notes: notes ?? this.notes,
      debtStatus: debtStatus ?? this.debtStatus,
      debtDate: debtDate ?? this.debtDate,
      paidDate: paidDate ?? this.paidDate,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      markedPaidBy: markedPaidBy ?? this.markedPaidBy,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
    );
  }

  // Getters
  bool get isOpen => debtStatus == 'open';
  bool get isPaid => debtStatus == 'paid';

  bool get isTransactionDebt => debtType == 'transaction';
  bool get isStoreSaleDebt => debtType == 'store_sale';

  String get debtTypeDisplay => isTransactionDebt ? 'معاملة محفظة' : 'بيع من المحل';
  String get debtStatusDisplay => isOpen ? 'مفتوح' : 'مسدد';

  IconData get debtTypeIcon =>
      isTransactionDebt ? Icons.swap_horiz : Icons.shopping_cart;

  Color get statusColor => isOpen ? AppColors.error : AppColors.success;

  int get daysSinceCreated =>
      DateTime.now().difference(debtDate.toDate()).inDays;
  String get formattedDebtDate => DateHelper.formatTimestamp(debtDate);
  String get formattedPaidDate =>
      paidDate != null ? DateHelper.formatTimestamp(paidDate!) : '';
  String get relativeDebtDate => DateHelper.getRelativeTime(debtDate.toDate());

  @override
  String toString() =>
      'DebtModel(id: $debtId, customer: $customerName, amount: $amountDue, status: $debtStatus)';
}