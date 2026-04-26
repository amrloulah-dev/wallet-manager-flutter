enum TransactionType {
  credit, // Deposit/Receive
  debit, // Transfer/Send
  other;

  String get nameAr {
    switch (this) {
      case TransactionType.credit:
        return 'إيداع / استلام';
      case TransactionType.debit:
        return 'تحويل / إرسال';
      case TransactionType.other:
        return 'أخرى';
    }
  }

  static TransactionType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'credit':
      case 'receive':
        return TransactionType.credit;
      case 'debit':
      case 'send':
        return TransactionType.debit;
      default:
        return TransactionType.other;
    }
  }

  @override
  String toString() => name;
}

enum PaymentStatus {
  paid,
  pending,
  failed;

  String get nameAr {
    switch (this) {
      case PaymentStatus.paid:
        return 'تم الدفع';
      case PaymentStatus.pending:
        return 'قيد الانتظار';
      case PaymentStatus.failed:
        return 'فشل';
    }
  }

  static PaymentStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pending':
        return PaymentStatus.pending;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.pending;
    }
  }

  @override
  String toString() => name;
}
