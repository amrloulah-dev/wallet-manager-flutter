enum UserRole {
  owner,
  employee;

  String get nameAr {
    switch (this) {
      case UserRole.owner:
        return 'صاحب العمل';
      case UserRole.employee:
        return 'موظف';
    }
  }

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'employee':
        return UserRole.employee;
      default:
        return UserRole.employee;
    }
  }

  @override
  String toString() => name;
}
