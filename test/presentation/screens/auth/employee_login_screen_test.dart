import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/auth/employee_login_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:walletmanager/core/enums/user_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockEmployeeProvider extends Mock implements EmployeeProvider {}

class FakeUserModel extends Fake implements UserModel {}

class FakeStoreModel extends Fake implements StoreModel {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUserModel());
    registerFallbackValue(FakeStoreModel());
  });

  late MockAuthProvider mockAuthProvider;
  late MockEmployeeProvider mockEmployeeProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockEmployeeProvider = MockEmployeeProvider();

    when(() => mockEmployeeProvider.setStoreId(any())).thenAnswer((_) async {});
    when(() => mockEmployeeProvider.isLoading).thenReturn(false);
    when(() => mockEmployeeProvider.hasError).thenReturn(false);
    when(() => mockEmployeeProvider.errorMessage).thenReturn(null);
    when(() => mockEmployeeProvider.activeEmployees).thenReturn([
      UserModel(
        userId: 'emp_1',
        email: 'emp@test.com',
        fullName: 'Test Employee',
        role: UserRole.employee,
        storeId: 'store_1',
        pin:
            '1234', // hashed pin matching test? actually the test will fail on PasswordHasher without mock, but the check is BEFORE login.
      )
    ]);
  });

  Widget buildTestableWidget(StoreModel store) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<EmployeeProvider>.value(
            value: mockEmployeeProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: Builder(builder: (context) {
            return EmployeeLoginScreen(store: store);
          }),
        ),
      ),
    );
  }

  testWidgets('Employee login aborts when subscription is expired',
      (tester) async {
    final expiredStore = StoreModel(
      storeId: 'store_1',
      storeName: 'Test Store',
      storePassword: 'hashed',
      ownerId: 'owner_1',
      ownerName: 'Owner',
      ownerEmail: 'owner@test.com',
      subscription: StoreSubscription(
        planId: SubscriptionPlan.proYearly,
        status: SubscriptionStatus.active,
        endDate: DateTime.now().subtract(const Duration(days: 10)),
        maxWallets: 3,
        maxEmployees: 1,
        trialConsumed: true,
        smsEnabled: true,
      ),
      settings: StoreSettings(),
      stats: StoreStats(),
    );

    await tester.pumpWidget(buildTestableWidget(expiredStore));
    await tester.pumpAndSettle();

    // Select employee (dropdown)
    // Wait, since we are just checking if it aborts, we don't even need to fully fill the form
    // Actually the check is AFTER form validation, inside _handleLogin.
    // We need to enter password, select employee, enter pin, and press login.

    // Enter store password
    await tester.enterText(find.byType(TextFormField).first, 'password123');

    // Select Employee Dropdown
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Employee').last);
    await tester.pumpAndSettle();

    // Enter PIN
    await tester.enterText(find.byType(TextFormField).last, '1234');

    // Tap Login
    await tester.tap(find.byIcon(Icons.login));
    await tester.pump(); // trigger toast

    // Verify loginAsEmployee was NEVER called
    verifyNever(() => mockAuthProvider.loginAsEmployee(any(), any()));

    // Check if toast is shown (toast uses root scaffold messenger usually, or custom overlay)
    // In ToastUtils, it usually uses fluttertoast or similar. We can just verify the block happened by loginAsEmployee not being called.
  });
}
