enum StoreStatus {
  active,
  inactive,
  suspended,
  pending;

  String get nameAr {
    switch (this) {
      case StoreStatus.active:
        return 'نشط';
      case StoreStatus.inactive:
        return 'غير نشط';
      case StoreStatus.suspended:
        return 'معلق';
      case StoreStatus.pending:
        return 'قيد الانتظار';
    }
  }

  static StoreStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return StoreStatus.active;
      case 'inactive':
        return StoreStatus.inactive;
      case 'suspended':
        return StoreStatus.suspended;
      case 'pending':
        return StoreStatus.pending;
      default:
        return StoreStatus.active;
    }
  }

  @override
  String toString() => name;
}
