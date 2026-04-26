enum DebtStatus {
  open,
  paid,
  partiallyPaid;

  String get nameAr {
    switch (this) {
      case DebtStatus.open:
        return 'مفتوح';
      case DebtStatus.paid:
        return 'تم الدفع';
      case DebtStatus.partiallyPaid:
        return 'دفع جزئي';
    }
  }

  static DebtStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return DebtStatus.open;
      case 'paid':
        return DebtStatus.paid;
      case 'partially_paid':
      case 'partiallypaid':
        return DebtStatus.partiallyPaid;
      default:
        return DebtStatus.open;
    }
  }

  @override
  String toString() => name;
}
