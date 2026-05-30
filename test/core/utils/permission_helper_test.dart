import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/permission_helper.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  late MockAuthProvider mockAuth;

  setUp(() {
    mockAuth = MockAuthProvider();
  });

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
      ],
      child: MaterialApp(home: child),
    );
  }

  group('PermissionHelper Tests', () {
    testWidgets(
        'canAccessScreen should return true for owners on sensitive routes',
        (tester) async {
      when(() => mockAuth.isOwner).thenReturn(true);

      await tester.pumpWidget(createTestWidget(Builder(builder: (context) {
        final canAccess = PermissionHelper.canAccessScreen(
            context, RouteConstants.manageEmployees);
        expect(canAccess, isTrue);
        return const SizedBox();
      })));
    });

    testWidgets(
        'canAccessScreen should return false for employees on employee management routes',
        (tester) async {
      final employee = UserModel(
        userId: 'u1',
        storeId: 's1',
        role: UserRole.employee,
        fullName: 'Employee',
        permissions: UserPermissions.defaultPermissions(),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuth.isOwner).thenReturn(false);
      when(() => mockAuth.currentUser).thenReturn(employee);

      await tester.pumpWidget(createTestWidget(Builder(builder: (context) {
        final canAccess = PermissionHelper.canAccessScreen(
            context, RouteConstants.manageEmployees);
        expect(canAccess, isFalse);
        return const SizedBox();
      })));
    });

    testWidgets(
        'canAccessScreen should return true for employees with specific permissions',
        (tester) async {
      final employee = UserModel(
        userId: 'u1',
        storeId: 's1',
        role: UserRole.employee,
        fullName: 'Employee',
        permissions:
            UserPermissions.defaultPermissions().copyWith(viewWallets: true),
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );

      when(() => mockAuth.isOwner).thenReturn(false);
      when(() => mockAuth.currentUser).thenReturn(employee);

      await tester.pumpWidget(createTestWidget(Builder(builder: (context) {
        final canAccess = PermissionHelper.canAccessScreen(
            context, RouteConstants.walletsList);
        expect(canAccess, isTrue);
        return const SizedBox();
      })));
    });
  });
}
