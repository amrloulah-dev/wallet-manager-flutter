enum WalletType {
  vodafoneCash,
  instaPay,
  orangeCash,
  etisalatCash,
  wePay,
  other;

  String get nameAr {
    switch (this) {
      case WalletType.vodafoneCash:
        return 'فودافون كاش';
      case WalletType.instaPay:
        return 'إنستا باي';
      case WalletType.orangeCash:
        return 'أورانج كاش';
      case WalletType.etisalatCash:
        return 'اتصالات كاش';
      case WalletType.wePay:
        return 'وي باي';
      case WalletType.other:
        return 'أخرى';
    }
  }

  String get dbValue {
    switch (this) {
      case WalletType.vodafoneCash:
        return 'vodafone_cash';
      case WalletType.instaPay:
        return 'instapay';
      case WalletType.orangeCash:
        return 'orange_cash';
      case WalletType.etisalatCash:
        return 'etisalat_cash';
      case WalletType.wePay:
        return 'we_pay';
      case WalletType.other:
        return 'other';
    }
  }

  static WalletType fromString(String type) {
    final sanitized = type.toLowerCase().trim().replaceAll(' ', '_');
    switch (sanitized) {
      case 'vodafone_cash':
        return WalletType.vodafoneCash;
      case 'instapay':
        return WalletType.instaPay;
      case 'orange_cash':
        return WalletType.orangeCash;
      case 'etisalat_cash':
        return WalletType.etisalatCash;
      case 'we_pay':
        return WalletType.wePay;
      default:
        return WalletType.other;
    }
  }

  @override
  String toString() => name;
}

enum WalletStatus {
  active,
  inactive,
  suspended;

  String get nameAr {
    switch (this) {
      case WalletStatus.active:
        return 'نشط';
      case WalletStatus.inactive:
        return 'غير نشط';
      case WalletStatus.suspended:
        return 'معلق';
    }
  }

  static WalletStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return WalletStatus.active;
      case 'inactive':
        return WalletStatus.inactive;
      case 'suspended':
        return WalletStatus.suspended;
      default:
        return WalletStatus.active;
    }
  }

  @override
  String toString() => name;
}
