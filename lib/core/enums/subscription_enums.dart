enum SubscriptionStatus {
  active,
  expired,
  suspended,
  pending;

  String get nameAr {
    switch (this) {
      case SubscriptionStatus.active:
        return 'نشط';
      case SubscriptionStatus.expired:
        return 'منتهي';
      case SubscriptionStatus.suspended:
        return 'معلق';
      case SubscriptionStatus.pending:
        return 'قيد الانتظار';
    }
  }

  static SubscriptionStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'suspended':
        return SubscriptionStatus.suspended;
      case 'pending':
        return SubscriptionStatus.pending;
      default:
        return SubscriptionStatus.pending;
    }
  }

  @override
  String toString() => name;
}

enum SubscriptionPlan {
  free,
  trial,
  proYearly,
  lifetime;

  String get nameAr {
    switch (this) {
      case SubscriptionPlan.free:
        return 'مجاني';
      case SubscriptionPlan.trial:
        return 'تجريبي';
      case SubscriptionPlan.proYearly:
        return 'احترافي سنوي';
      case SubscriptionPlan.lifetime:
        return 'مدى الحياة';
    }
  }

  static SubscriptionPlan fromString(String plan) {
    switch (plan.toLowerCase()) {
      case 'free':
        return SubscriptionPlan.free;
      case 'trial':
        return SubscriptionPlan.trial;
      case 'pro_yearly':
        return SubscriptionPlan.proYearly;
      case 'lifetime':
        return SubscriptionPlan.lifetime;
      default:
        return SubscriptionPlan.free;
    }
  }

  @override
  String toString() => name;
}
