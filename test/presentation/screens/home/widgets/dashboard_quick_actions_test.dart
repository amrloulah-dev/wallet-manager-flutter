import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/home/widgets/dashboard_quick_actions.dart';
import 'package:walletmanager/presentation/widgets/dashboard/quick_action_card.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/user_permissions.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockStatisticsProvider extends Mock implements StatisticsProvider {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockStatisticsProvider mockStatisticsProvider;
  late MockNavigatorObserver mockNavigatorObserver;

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockStatisticsProvider = MockStatisticsProvider();
    mockNavigatorObserver = MockNavigatorObserver();

    // Use default constructor or mock StatsSummaryModel
    mockStatisticsProvider = MockStatisticsProvider();
    when(() => mockStatisticsProvider.dashboardSummary).thenReturn(
      StatsSummaryModel(
        totalWallets: 2,
        totalTransactions: 10,
        totalCommission: 50.0,
        openDebtsCount: 3,
        totalOpenAmount: 300.0,
        totalBalance: 1000.0,
      ),
    );

    final mockUser = UserModel(
      userId: 'user_123',
      storeId: 'store_123',
      fullName: 'Test Owner',
      phone: '01000000000',
      role: UserRole.owner,
      permissions: UserPermissions(
        createTransaction: true,
        createWallet: true,
        createDebt: true,
        viewWallets: true,
        viewDebts: true,
        viewDashboardStats: true,
      ),
    );
    when(() => mockAuthProvider.currentUser).thenReturn(mockUser);
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<StatisticsProvider>.value(
            value: mockStatisticsProvider),
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
          body: CustomScrollView(
            slivers: [
              const DashboardQuickActions(),
            ],
          ),
        ),
        navigatorObservers: [mockNavigatorObserver],
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) =>
                Scaffold(body: Text('Route: ${settings.name}')),
            settings: settings,
          );
        },
      ),
    );
  }

  testWidgets(
      'DashboardQuickActions contains Add Balance card and navigates to route on tap',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify "Add Balance" card exists in the list
    final addBalanceFinder =
        find.widgetWithText(QuickActionCard, 'Add Balance');
    expect(addBalanceFinder, findsOneWidget);

    // Tap it to verify navigation
    await tester.tap(addBalanceFinder);
    await tester.pumpAndSettle();

    // Verify navigator pushed RouteConstants.addBalance
    verify(() => mockNavigatorObserver.didPush(any(), any()))
        .called(2); // Initial route + Add Balance
  });
}
