import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/subscription/subscription_details_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/employee_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockWalletProvider extends Mock implements WalletProvider {}
class MockEmployeeProvider extends Mock implements EmployeeProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockWalletProvider mockWalletProvider;
  late MockEmployeeProvider mockEmployeeProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();
    mockEmployeeProvider = MockEmployeeProvider();

    // Mock initial state
    when(() => mockWalletProvider.isLoading).thenReturn(false);
    when(() => mockWalletProvider.wallets).thenReturn([]);
    when(() => mockWalletProvider.refresh()).thenAnswer((_) async {});

    when(() => mockEmployeeProvider.isLoading).thenReturn(false);
    when(() => mockEmployeeProvider.employeesCount).thenReturn(0);
    when(() => mockEmployeeProvider.refresh()).thenAnswer((_) {}); // refresh() in EmployeeProvider is void, wait let me check, or maybe async. If error I'll fix

    when(() => mockAuthProvider.currentStore).thenReturn(
      StoreModel(
        storeId: 'store_1',
        storeName: 'Test Store',
        storePassword: 'password123',
        ownerId: 'owner_1',
        ownerName: 'Owner Name',
        ownerEmail: 'owner@example.com',
        createdAt: DateTime.now(),
        subscription: StoreSubscription(
          planId: SubscriptionPlan.proYearly,
          status: SubscriptionStatus.active,
          maxWallets: 50,
          maxEmployees: 20,
          trialConsumed: false,
          smsEnabled: true,
        ),
        settings: StoreSettings(),
        stats: StoreStats(),
      ),
    );
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
        ChangeNotifierProvider<EmployeeProvider>.value(value: mockEmployeeProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const SubscriptionDetailsScreen(),
      ),
    );
  }

  group('SubscriptionDetailsScreen Widget Tests', () {
    testWidgets('Fetches data on load in initState', (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      verify(() => mockWalletProvider.refresh()).called(1);
      verify(() => mockEmployeeProvider.refresh()).called(1);
    });

    testWidgets('Displays loading indicator when status is loading', (tester) async {
      when(() => mockWalletProvider.isLoading).thenReturn(true);
      when(() => mockEmployeeProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(buildTestableWidget());
      
      // We should see CircularProgressIndicator for wallets and employees
      // There's one main Scaffold loading if subscription is null, but subscription is NOT null here
      // The CircularProgressIndicator are in _buildLimitItem
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
    });
  });
}
