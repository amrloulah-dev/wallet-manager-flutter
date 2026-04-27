import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/utils/number_parser.dart';
import '../../core/utils/amount_validator.dart';
import '../../core/enums/debt_enums.dart';
import '../../core/errors/app_error_handler.dart';

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
  final DateTime? debtDate; // Made nullable
  final DateTime? paidDate; 

  // Tracking
  final String createdBy; 
  final DateTime? createdAt; // Made nullable
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
    this.debtDate,
    this.paidDate,
    required this.createdBy,
    this.createdAt,
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
    final totalAmount = NumberParser.toDouble(data['totalAmount']);

    // VALIDATION: Ensure amounts are positive (P1-8 FIX)
    AmountValidator.ensurePositive(amountDue);
    AmountValidator.ensurePositive(totalAmount);

    // Fallback for old data where totalAmount didn't exist
    if (totalAmount == 0.0 && debtStatus == DebtStatus.open) {
      // If totalAmount was zero but now passes validation, it means data is inconsistent
      // This should not happen with the new validation
      AppErrorHandler.handle(
        'Debt document has zero totalAmount: ${doc.id}',
        operation: 'DebtModel.fromFirestore',
      );
    }

    final debtDate = (data['debtDate'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    if (debtDate == null || createdAt == null) {
      AppErrorHandler.handle(
        'Missing timestamps in Debt document: ${doc.id}',
        operation: 'DebtModel.fromFirestore',
      );
    }

    return DebtModel(
      debtId: doc.id,
      storeId: data[FirebaseConstants.storeId] as String? ?? '',
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      debtType: debtType,
      amountDue: amountDue,
      totalAmount: totalAmount,
      notes: data[FirebaseConstants.notes] as String?,
      debtStatus: debtStatus,
      debtDate: debtDate,
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      createdBy: data[FirebaseConstants.createdBy] as String? ?? '',
      createdAt: createdAt,
      markedPaidBy: data['markedPaidBy'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastUpdatedBy: data['lastUpdatedBy'] as String?,
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
      'debtDate': debtDate != null ? Timestamp.fromDate(debtDate!) : null,
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      FirebaseConstants.createdBy: createdBy,
      FirebaseConstants.createdAt: createdAt != null ? Timestamp.fromDate(createdAt!) : null,
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
