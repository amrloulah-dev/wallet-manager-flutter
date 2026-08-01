import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/presentation/screens/settings/widgets/account_info_section.dart';
import 'package:walletmanager/presentation/screens/subscription/payment_modal_screen.dart';
import 'package:walletmanager/presentation/screens/subscription/paywall_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/system_config_provider.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';
import 'package:walletmanager/data/models/system_configs_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}
class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}
class MockSystemConfigProvider extends Mock implements SystemConfigProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;
  late MockSystemConfigProvider mockSystemConfigProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();
    mockPlatformSettingsProvider = MockPlatformSettingsProvider();
    mockSystemConfigProvider = MockSystemConfigProvider();

    when(() => mockAuthProvider.isTrial).thenReturn(false);
    when(() => mockAuthProvider.trialDaysRemaining).thenReturn(null);
    when(() => mockAuthProvider.currentUser).thenReturn(
      UserModel(
        userId: 'u1',
        email: 'test@test.com',
        fullName: 'Test Owner',
        phone: '01000000000',
        storeId: 's1',
        role: UserRole.owner,
        createdAt: DateTime.now(),
      ),
    );
    when(() => mockAuthProvider.currentStore).thenReturn(
      StoreModel(
        storeId: 's1',
        storeName: 'Test Store',
        storePassword: 'pwd',
        ownerId: 'u1',
        ownerName: 'Test Owner',
        ownerEmail: 'test@test.com',
        subscription: StoreSubscription(
          planId: SubscriptionPlan.lifetime,
          status: SubscriptionStatus.active,
          endDate: null,
          trialConsumed: true,
        ),
        settings: StoreSettings(),
      ),
    );

    when(() => mockSubscriptionProvider.isExpired).thenReturn(false);
    when(() => mockSubscriptionProvider.daysRemaining).thenReturn(null);

    when(() => mockPlatformSettingsProvider.settings).thenReturn(
      const PlatformSettingsModel(
        isRegistrationOpen: true,
        instapayLimits: NetworkLimits(dailyReceive: 1, dailySend: 1, maxPerTransaction: 1, monthlyReceive: 1, monthlySend: 1),
        networkCommercialLimits: NetworkLimits(dailyReceive: 1, dailySend: 1, maxPerTransaction: 1, monthlyReceive: 1, monthlySend: 1),
        networkNewLimits: NetworkLimits(dailyReceive: 1, dailySend: 1, maxPerTransaction: 1, monthlyReceive: 1, monthlySend: 1),
        networkOldLimits: NetworkLimits(dailyReceive: 1, dailySend: 1, maxPerTransaction: 1, monthlyReceive: 1, monthlySend: 1),
        minCrossNetworkFee: 0,
        maxCrossNetworkFee: 0,
        minInstapayFee: 0,
        maxInstapayFee: 0,
        sameNetworkFee: 0,
        crossNetworkFeeRate: 0,
        instapayFeeRate: 0,
        lifetimeCountLimit: 50,
        gracePeriodHours: 48,
        trialDays: 14,
        plans: {
          'proyearly': SubscriptionPlanModel(
            name: 'Pro Yearly',
            price: 1000,
            maxWallets: 10,
            maxEmployees: 10,
            smsEnabled: true,
            description: 'Pro plan',
            isActive: true,
          ),
        },
      ),
    );
    when(() => mockSystemConfigProvider.configs).thenReturn(
      SystemConfigsModel(),
    );
  });

  Widget makeTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: mockSubscriptionProvider),
        ChangeNotifierProvider<PlatformSettingsProvider>.value(value: mockPlatformSettingsProvider),
        ChangeNotifierProvider<SystemConfigProvider>.value(value: mockSystemConfigProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        locale: const Locale('ar'),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('AccountInfoSection displays ∞ symbol for lifetime subscription', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const AccountInfoSection()));
    await tester.pumpAndSettle();

    expect(find.text('∞'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  testWidgets('PaywallScreen has sticky bottomNavigationBar with continue button', (tester) async {
    await tester.pumpWidget(makeTestableWidget(const PaywallScreen()));
    await tester.pumpAndSettle();

    final scaffoldFinder = find.byType(Scaffold).last;
    expect(scaffoldFinder, findsOneWidget);
    final Scaffold scaffold = tester.widget(scaffoldFinder);
    expect(scaffold.bottomNavigationBar, isNotNull);
  });

  testWidgets('PaymentModalScreen renders InstaPay without method selectors', (tester) async {
    await tester.pumpWidget(makeTestableWidget(
      const PaymentModalScreen(planId: SubscriptionPlan.lifetime),
    ));
    await tester.pumpAndSettle();

    expect(find.text('فودافون كاش'), findsNothing);
    expect(find.byIcon(Icons.phone_android), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });
}
