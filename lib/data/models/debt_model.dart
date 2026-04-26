import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/utils/number_parser.dart';
import '../../core/enums/debt_enums.dart';

class DebtModel {
  // Identity
  final String debtId;
  final String storeId;

  // Customer Info
  final String customerName;
  final String customerPhone;

  // Debt Details
  final DebtType debtType; // ENUM refactor
  final double amountDue; 
  final double totalAmount; 
  final String? notes;

  // Status
  final DebtStatus debtStatus; // ENUM refactor

  // Dates
  final DateTime debtDate; 
  final DateTime? paidDate; 

  // Tracking
  final String createdBy; 
  final DateTime createdAt;
  final String? markedPaidBy; 
  final DateTime? updatedAt;
  final String? lastUpdatedBy;

  final String customerNameNormalized;

  DebtModel({
    required this.debtId,
    required this.storeId,
    required this.customerName,
    required this.customerPhone,
    required this.debtType,
    required this.amountDue,
    required this.totalAmount,
    this.notes,
    this.debtStatus = DebtStatus.open,
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

    final statusStr = data['debtStatus'] as String? ?? 'open';
    final debtStatus = DebtStatus.fromString(statusStr);
    
    final typeStr = data['debtType'] as String? ?? 'store_sale';
    final debtType = DebtType.fromString(typeStr);

    final amountDue = NumberParser.toDouble(data['amountDue']);

    // Fallback for old data where totalAmount didn't exist
    double totalAmount = NumberParser.toDouble(data['totalAmount']);
    if (totalAmount == 0.0 && debtStatus == DebtStatus.open) {
      totalAmount = amountDue;
    }

    return DebtModel(
      debtId: doc.id,
      storeId: data[FirebaseConstants.storeId] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      debtType: debtType,
      amountDue: amountDue,
      totalAmount: totalAmount,
      notes: data[FirebaseConstants.notes],
      debtStatus: debtStatus,
      debtDate: (data['debtDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      createdBy: data[FirebaseConstants.createdBy] ?? '',
      createdAt: (data[FirebaseConstants.createdAt] as Timestamp?)?.toDate() ?? DateTime.now(),
      markedPaidBy: data['markedPaidBy'],
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastUpdatedBy: data['lastUpdatedBy'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.storeId: storeId,
      'customerName': customerName,
      'customerNameNormalized': customerNameNormalized,
      'customerPhone': customerPhone,
      'debtType': debtType.name,
      'amountDue': amountDue,
      'totalAmount': totalAmount,
      FirebaseConstants.notes: notes,
      'debtStatus': debtStatus.name,
      'debtDate': Timestamp.fromDate(debtDate),
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      FirebaseConstants.createdBy: createdBy,
      FirebaseConstants.createdAt: Timestamp.fromDate(createdAt),
      'markedPaidBy': markedPaidBy,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'lastUpdatedBy': lastUpdatedBy,
    };
  }

  DebtModel copyWith({
    String? debtId,
    String? storeId,
    String? customerName,
    String? customerPhone,
    DebtType? debtType,
    double? amountDue,
    double? totalAmount,
    String? notes,
    DebtStatus? debtStatus,
    DateTime? debtDate,
    DateTime? paidDate,
    String? createdBy,
    DateTime? createdAt,
    String? markedPaidBy,
    DateTime? updatedAt,
    String? lastUpdatedBy,
  }) {
    return DebtModel(
      debtId: debtId ?? this.debtId,
      storeId: storeId ?? this.storeId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      debtType: debtType ?? this.debtType,
      amountDue: amountDue ?? this.amountDue,
      totalAmount: totalAmount ?? this.totalAmount,
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
  bool get isOpen => debtStatus == DebtStatus.open;
  bool get isPaid => debtStatus == DebtStatus.paid;

  bool get isTransactionDebt => debtType == DebtType.transaction;
  bool get isStoreSaleDebt => debtType == DebtType.storeSale;

  @override
  String toString() =>
      'DebtModel(id: $debtId, customer: $customerName, amountDue: $amountDue, totalAmount: $totalAmount)';
}
