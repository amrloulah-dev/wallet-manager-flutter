import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/employees/manage_employees_screen.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';

class DummyEmployeeProvider extends ChangeNotifier implements EmployeeProvider {
  @override
  bool get isLoading => false;
  @override
  bool get hasError => false;
  @override
  List<UserModel> get employees => [
    UserModel(userId: '1', storeId: 's1', role: UserRole.employee, fullName: 'Emp 1', email: 'e1@t.com', isActive: true),
    UserModel(userId: '2', storeId: 's1', role: UserRole.employee, fullName: 'Emp 2', email: 'e2@t.com', isActive: false),
  ];
  @override
  List<UserModel> get activeEmployees => [employees[0]];
  @override
  List<UserModel> get inactiveEmployees => [employees[1]];
  @override
  bool isEmployeeFrozen(UserModel employee) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('ManageEmployeesScreen should use CustomScrollView and SliverList for efficiency', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<EmployeeProvider>(
        create: (_) => DummyEmployeeProvider(),
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: ManageEmployeesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify it uses CustomScrollView (Slivers)
    final customScrollViewFinder = find.byType(CustomScrollView);
    expect(customScrollViewFinder, findsOneWidget, reason: 'Should use CustomScrollView instead of ListView');

    // Verify it does NOT use shrinkWrap: true in any ListView
    final listViewFinder = find.byType(ListView);
    if (listViewFinder.evaluate().isNotEmpty) {
      for (final widget in tester.widgetList<ListView>(listViewFinder)) {
        expect(widget.shrinkWrap, isFalse, reason: 'No ListView should use shrinkWrap: true');
      }
    }
  });
}
