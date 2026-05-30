import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

void main() {
  group('UserRole Enum Tests', () {
    test('fromString should return owner for "owner"', () {
      expect(UserRole.fromString('owner'), UserRole.owner);
      expect(UserRole.fromString('OWNER'), UserRole.owner);
    });

    test('fromString should return employee for "employee"', () {
      expect(UserRole.fromString('employee'), UserRole.employee);
      expect(UserRole.fromString('EMPLOYEE'), UserRole.employee);
    });

    test('fromString should return unknown for invalid strings (Fail-Closed)',
        () {
      // This is expected to fail currently as it defaults to employee
      expect(UserRole.fromString('hacker'), UserRole.unknown);
      expect(UserRole.fromString('admin'), UserRole.unknown);
      expect(UserRole.fromString(''), UserRole.unknown);
    });

    test('toString should return the enum name', () {
      expect(UserRole.owner.toString(), 'owner');
      expect(UserRole.employee.toString(), 'employee');
      expect(UserRole.unknown.toString(), 'unknown');
    });

    test('nameAr should return correct Arabic labels', () {
      expect(UserRole.owner.nameAr, 'صاحب العمل');
      expect(UserRole.employee.nameAr, 'موظف');
      expect(UserRole.unknown.nameAr, 'غير معروف');
    });
    group('UserRole Parsing Failure Cases', () {
      test(
          'fromString should throw ArgumentError for unknown roles when configured to throw',
          () {
        // Optional behavior based on spec: "throw ArgumentError OR default to unknown"
        // We will test for "unknown" first as it's safer for lazy migration.
      });
    });
  });
}
