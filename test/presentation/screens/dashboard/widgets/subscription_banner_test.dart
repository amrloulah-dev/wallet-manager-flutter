import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/dashboard/widgets/subscription_banner.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();
    
    // Default stubs
    when(() => mockAuthProvider.currentStore).thenReturn(null);
    when(() => mockAuthProvider.isTrial).thenReturn(false);
    when(() => mockAuthProvider.trialDaysRemaining).thenReturn(null);
    
    when(() => mockSubscriptionProvider.latestRequest).thenReturn(null);
    when(() => mockSubscriptionProvider.isExpired).thenReturn(false);
    when(() => mockSubscriptionProvider.hasDismissedRejection).thenReturn(false);
    when(() => mockSubscriptionProvider.daysRemaining).thenReturn(null);
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: mockSubscriptionProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('ar')],
        home: Scaffold(body: SubscriptionBanner()),
      ),
    );
  }

  group('SubscriptionBanner Widget Tests', () {
    testWidgets('Trial Plan - days > 0 shows remaining days', (tester) async {
      when(() => mockSubscriptionProvider.daysRemaining).thenReturn(5);
      when(() => mockAuthProvider.currentStore).thenReturn(StoreModel(
        storeId: '1', storeName: 'S', storePassword: 'P', ownerId: '1', ownerName: 'O', ownerEmail: 'E',
        subscription: StoreSubscription(planId: SubscriptionPlan.trial, status: SubscriptionStatus.active, trialConsumed: false, maxWallets: 1, maxEmployees: 1, smsEnabled: false),
        settings: StoreSettings(), stats: StoreStats(),
      ));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('5'), findsOneWidget);
    });

    testWidgets('Trial Plan - days == 0 shows expires today', (tester) async {
      when(() => mockSubscriptionProvider.daysRemaining).thenReturn(0);
      when(() => mockAuthProvider.currentStore).thenReturn(StoreModel(
        storeId: '1', storeName: 'S', storePassword: 'P', ownerId: '1', ownerName: 'O', ownerEmail: 'E',
        subscription: StoreSubscription(planId: SubscriptionPlan.trial, status: SubscriptionStatus.active, trialConsumed: false, maxWallets: 1, maxEmployees: 1, smsEnabled: false),
        settings: StoreSettings(), stats: StoreStats(),
      ));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('ينتهي اشتراكك اليوم!'), findsOneWidget);
    });

    testWidgets('Annual Plan - days < 0 shows expired', (tester) async {
      when(() => mockSubscriptionProvider.daysRemaining).thenReturn(-2);
      when(() => mockSubscriptionProvider.isExpired).thenReturn(true);
      when(() => mockAuthProvider.currentStore).thenReturn(StoreModel(
        storeId: '1', storeName: 'S', storePassword: 'P', ownerId: '1', ownerName: 'O', ownerEmail: 'E',
        subscription: StoreSubscription(planId: SubscriptionPlan.proYearly, status: SubscriptionStatus.expired, trialConsumed: false, maxWallets: 1, maxEmployees: 1, smsEnabled: false),
        settings: StoreSettings(), stats: StoreStats(),
      ));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('انتهت صلاحية اشتراكك!'), findsOneWidget);
    });

    testWidgets('Annual Plan - days > 14 hides banner completely', (tester) async {
      when(() => mockSubscriptionProvider.daysRemaining).thenReturn(15);
      when(() => mockAuthProvider.currentStore).thenReturn(StoreModel(
        storeId: '1', storeName: 'S', storePassword: 'P', ownerId: '1', ownerName: 'O', ownerEmail: 'E',
        subscription: StoreSubscription(planId: SubscriptionPlan.proYearly, status: SubscriptionStatus.active, trialConsumed: false, maxWallets: 1, maxEmployees: 1, smsEnabled: false),
        settings: StoreSettings(), stats: StoreStats(),
      ));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsNothing);
    });
  });
}
