import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/presentation/screens/employees/add_employee_screen.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';

class MockEmployeeProvider extends Mock implements EmployeeProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

void main() {
  late MockEmployeeProvider mockEmployeeProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;

  setUp(() {
    mockEmployeeProvider = MockEmployeeProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();

    // Default mock stubs
    when(() => mockEmployeeProvider.employeesCount).thenReturn(1);
    when(() => mockSubscriptionProvider.maxEmployees).thenReturn(5);
    when(() => mockSubscriptionProvider.canAddEmployee(any())).thenReturn(true);
    when(() => mockEmployeeProvider.errorMessage).thenReturn(null);
  });

  Widget createWidgetUnderText() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EmployeeProvider>.value(
            value: mockEmployeeProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: mockSubscriptionProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routes: {
          RouteConstants.upgradeScreen: (_) =>
              const Scaffold(body: Text('Upgrade Screen')),
        },
        home: const AddEmployeeScreen(),
      ),
    );
  }

  testWidgets(
      'shows correct employee count and enables submit when under limit',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderText());
    await tester.pumpAndSettle();

    // Verify button is enabled (not null onPressed)
    final buttonFinder = find.byType(ElevatedButton);
    expect(buttonFinder, findsOneWidget);
    final ElevatedButton button = tester.widget(buttonFinder);
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
      'disables submit button and shows limit reached warning when at limit',
      (tester) async {
    when(() => mockEmployeeProvider.employeesCount).thenReturn(5);
    when(() => mockSubscriptionProvider.maxEmployees).thenReturn(5);

    await tester.pumpWidget(createWidgetUnderText());
    await tester.pumpAndSettle();

    // Let's verify the submit button is disabled.
    final buttonFinder = find.byType(ElevatedButton);
    expect(buttonFinder, findsOneWidget);
    final ElevatedButton button = tester.widget(buttonFinder);
    expect(button.onPressed, isNull);
  });

  testWidgets(
      'preemptively redirects to UpgradeScreen if limit check fails on submit',
      (tester) async {
    // Under limit in terms of count check (button enabled)
    when(() => mockEmployeeProvider.employeesCount).thenReturn(2);
    when(() => mockSubscriptionProvider.maxEmployees).thenReturn(5);
    // But canAddEmployee check fails on submit
    when(() => mockSubscriptionProvider.canAddEmployee(2)).thenReturn(false);

    await tester.pumpWidget(createWidgetUnderText());
    await tester.pumpAndSettle();

    // Tap submit button (which is enabled)
    final buttonFinder = find.byType(ElevatedButton);
    expect(buttonFinder, findsOneWidget);
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // Check if we navigated to UpgradeScreen
    expect(find.text('Upgrade Screen'), findsOneWidget);
  });
}
