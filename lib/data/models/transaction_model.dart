import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/firebase_constants.dart';
import '../../core/utils/number_parser.dart';
import '../../core/enums/transaction_enums.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/utils/amount_validator.dart';

class TransactionModel {
  final String transactionId;
  final String storeId;
  final String walletId;
  final TransactionType transactionType; // ENUM refactor
  final String? customerPhone;
  final String? customerName;
  final double amount;
  final double commission;
  final double serviceFee; // Fee charged by the network/service
  final PaymentStatus paymentStatus; // ENUM refactor
  final String? debtId;
  final String? notes;
  final DateTime? transactionDate; // Made nullable
  final DateTime? createdAt; // Made nullable
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
    this.paymentStatus = PaymentStatus.paid,
    this.debtId,
    this.notes,
    this.transactionDate,
    this.createdAt,
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
    return TransactionModel.fromMap(data, doc.id);
  }

  factory TransactionModel.fromMap(Map<String, dynamic> data, String docId) {
    final transactionDate = (data['transactionDate'] as Timestamp?)?.toDate();
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    if (transactionDate == null || createdAt == null) {
      throw NotFoundException(
        'Transaction document $docId missing required timestamps (transactionDate or createdAt)'
      );
    }

    final amount = NumberParser.toDouble(data['amount']);
    final commission = NumberParser.toDouble(data['commission']);
    final serviceFee = NumberParser.toDouble(data['serviceFee']);

    // Phase 3: Domain Model Purity Guards
    AmountValidator.ensurePositive(amount);
    AmountValidator.ensurePositiveOrZero(commission);
    AmountValidator.ensurePositiveOrZero(serviceFee);

    return TransactionModel(
      transactionId: docId,
      storeId: data[FirebaseConstants.storeId] as String? ?? '',
      walletId: data[FirebaseConstants.walletId] as String? ?? '',
      transactionType: TransactionType.fromString(data['transactionType'] as String? ?? 'send'),
      customerPhone: data['customerPhone'] as String?,
      customerName: data['customerName'] as String?,
      amount: amount,
      commission: commission,
      serviceFee: serviceFee,
      paymentStatus: PaymentStatus.fromString(data['paymentStatus'] as String? ?? 'paid'),
      debtId: data['debtId'] as String?,
      notes: data[FirebaseConstants.notes] as String?,
      transactionDate: transactionDate,
      createdAt: createdAt,
      createdBy: data[FirebaseConstants.createdBy] as String? ?? '',
      createdById: data['createdById'] as String?,
      createdByName: data['createdByName'] as String?,
      creatorRole: data['creatorRole'] as String?,
      updatedAt: (data[FirebaseConstants.updatedAt] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      deletedBy: data['deletedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      FirebaseConstants.storeId: storeId,
      FirebaseConstants.walletId: walletId,
      'transactionType': transactionType.name,
      'customerPhone': customerPhone,
      'customerName': customerName,
      'amount': amount,
      'commission': commission,
      'serviceFee': serviceFee,
      'paymentStatus': paymentStatus.name,
      'debtId': debtId,
      FirebaseConstants.notes: notes,
      'transactionDate': transactionDate != null ? Timestamp.fromDate(transactionDate!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
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
    TransactionType? transactionType,
    String? customerPhone,
    String? customerName,
    double? amount,
    double? commission,
    double? serviceFee,
    PaymentStatus? paymentStatus,
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
  bool get isSend => transactionType == TransactionType.debit;
  bool get isReceive => transactionType == TransactionType.credit;
  bool get isDeposit => transactionType == TransactionType.deposit;
  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isDebt => paymentStatus == PaymentStatus.debt;
  double get totalAmount =>
      amount + commission; // Original total amount (base + comm)

  @override
  String toString() {
    return 'TransactionModel(id: $transactionId, type: $transactionType, amount: $amount, serviceFee: $serviceFee, status: $paymentStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TransactionModel &&
        other.transactionId == transactionId &&
        other.storeId == storeId &&
        other.walletId == walletId &&
        other.transactionType == transactionType &&
        other.amount == amount &&
        other.commission == commission &&
        other.serviceFee == serviceFee &&
        other.paymentStatus == paymentStatus &&
        other.debtId == debtId &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode =>
      transactionId.hashCode ^
      storeId.hashCode ^
      walletId.hashCode ^
      transactionType.hashCode ^
      amount.hashCode ^
      commission.hashCode ^
      serviceFee.hashCode ^
      paymentStatus.hashCode ^
      debtId.hashCode ^
      isDeleted.hashCode;
}
