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

enum DebtType {
  transaction,
  storeSale;

  String get nameAr {
    switch (this) {
      case DebtType.transaction:
        return 'عملية';
      case DebtType.storeSale:
        return 'بيع من المتجر';
    }
  }

  static DebtType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'transaction':
        return DebtType.transaction;
      case 'store_sale':
      case 'storesale':
        return DebtType.storeSale;
      default:
        return DebtType.storeSale;
    }
  }

  @override
  String toString() => name;
}
