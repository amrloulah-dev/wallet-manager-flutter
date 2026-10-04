enum UserRole {
  owner,
  employee,
  unknown;

  String get nameAr {
    switch (this) {
      case UserRole.owner:
        return 'صاحب العمل';
      case UserRole.employee:
        return 'موظف';
      case UserRole.unknown:
        return 'غير معروف';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'employee':
        return UserRole.employee;
      default:
        // Fail-Closed: Default to unknown instead of employee
        return UserRole.unknown;
    }
  }

  @override
  String toString() => name;
}
