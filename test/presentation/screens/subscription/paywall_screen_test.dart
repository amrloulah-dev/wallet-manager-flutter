import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/presentation/screens/subscription/paywall_screen.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/providers/system_config_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/system_configs_model.dart';
import 'package:walletmanager/data/models/subscription_plan_model.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

class MockSystemConfigProvider extends Mock implements SystemConfigProvider {}

void main() {
  late MockPlatformSettingsProvider mockSettingsProvider;
  late MockSystemConfigProvider mockConfigProvider;

  setUpAll(() {
    registerFallbackValue(const PlatformSettingsModel.defaults());
  });

  setUp(() {
    mockSettingsProvider = MockPlatformSettingsProvider();
    mockConfigProvider = MockSystemConfigProvider();

    final sl = GetIt.instance;
    if (sl.isRegistered<PlatformSettingsProvider>()) {
      sl.unregister<PlatformSettingsProvider>();
    }
    sl.registerSingleton<PlatformSettingsProvider>(mockSettingsProvider);

    when(() => mockSettingsProvider.addListener(any())).thenReturn(null);
    when(() => mockSettingsProvider.removeListener(any())).thenReturn(null);
    when(() => mockConfigProvider.addListener(any())).thenReturn(null);
    when(() => mockConfigProvider.removeListener(any())).thenReturn(null);
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<PlatformSettingsProvider>.value(
            value: mockSettingsProvider),
        ChangeNotifierProvider<SystemConfigProvider>.value(
            value: mockConfigProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('en'),
        home: child,
      ),
    );
  }

  testWidgets('renders plans from catalog filtered by isActive and sorted',
      (WidgetTester tester) async {
    const plans = {
      'lifetime': SubscriptionPlanModel(
        name: 'Lifetime Plan',
        description: 'Lifetime VIP access',
        isActive: true,
        price: 2500,
        maxWallets: -1,
        maxEmployees: -1,
        smsEnabled: true,
      ),
      'trial': SubscriptionPlanModel(
        name: 'Trial Plan',
        description: 'Trial access',
        isActive: true,
        price: 0,
        maxWallets: 5,
        maxEmployees: 5,
        smsEnabled: false,
      ),
      'inactive_plan': SubscriptionPlanModel(
        name: 'Inactive Plan',
        description: 'Should not render',
        isActive: false,
        price: 99,
        maxWallets: 2,
        maxEmployees: 2,
        smsEnabled: false,
      ),
      'proYearly': SubscriptionPlanModel(
        name: 'Pro Yearly',
        description: 'Annual premium',
        isActive: true,
        price: 1200,
        maxWallets: 50,
        maxEmployees: 20,
        smsEnabled: true,
      ),
    };

    final settings = PlatformSettingsModel(
      isRegistrationOpen: true,
      instapayLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkCommercialLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkNewLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkOldLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
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
      plans: plans,
    );

    when(() => mockSettingsProvider.settings).thenReturn(settings);

    final systemConfigs = SystemConfigsModel(
      lifetimePlanEnabled: true,
      remainingLifetimeSeats: 10,
    );
    when(() => mockConfigProvider.configs).thenReturn(systemConfigs);

    await tester.pumpWidget(buildTestableWidget(const PaywallScreen()));

    // Verify Active plans are displayed
    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('Pro Yearly Plan'), findsOneWidget);
    expect(find.text('Lifetime VIP Plan'), findsOneWidget);

    // Verify Inactive plan is not displayed
    expect(find.text('Inactive Plan'), findsNothing);

    // Verify dynamic prices are displayed via string interpolation
    expect(find.text('Free Trial'), findsOneWidget);
    expect(find.text('1200 EGP / year'), findsOneWidget);
    expect(find.text('2500 EGP one-time only'), findsOneWidget);

    // Check sorting ordering by verifying visual order of plan cards:
    // Sorted should be: Trial, Pro Yearly, Lifetime
    final listFinder = find.byType(Column);
    final textWidgets = tester
        .widgetList<Text>(find.descendant(
          of: listFinder,
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .toList();

    final trialIndex = textWidgets.indexOf('Trial');
    final proIndex = textWidgets.indexOf('Pro Yearly Plan');
    final lifetimeIndex = textWidgets.indexOf('Lifetime VIP Plan');

    expect(trialIndex < proIndex, isTrue);
    expect(proIndex < lifetimeIndex, isTrue);
  });

  testWidgets('gracefully handles empty catalog with fallback UI',
      (WidgetTester tester) async {
    final settings = PlatformSettingsModel(
      isRegistrationOpen: true,
      instapayLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkCommercialLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkNewLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkOldLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
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
      plans: const {}, // Empty catalog
    );

    when(() => mockSettingsProvider.settings).thenReturn(settings);

    final systemConfigs = SystemConfigsModel(
      lifetimePlanEnabled: true,
      remainingLifetimeSeats: 10,
    );
    when(() => mockConfigProvider.configs).thenReturn(systemConfigs);

    await tester.pumpWidget(buildTestableWidget(const PaywallScreen()));

    expect(find.text('No subscription plans available at the moment.'),
        findsOneWidget);
  });

  testWidgets('lifetime plan respects SystemConfigProvider visibility',
      (WidgetTester tester) async {
    const plans = {
      'lifetime': SubscriptionPlanModel(
        name: 'Lifetime Plan',
        description: 'Lifetime VIP access',
        isActive: true,
        price: 2500,
        maxWallets: -1,
        maxEmployees: -1,
        smsEnabled: true,
      ),
    };

    final settings = PlatformSettingsModel(
      isRegistrationOpen: true,
      instapayLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkCommercialLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkNewLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
      networkOldLimits: const NetworkLimits(
          dailyReceive: 0,
          dailySend: 0,
          maxPerTransaction: 0,
          monthlyReceive: 0,
          monthlySend: 0),
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
      plans: plans,
    );

    when(() => mockSettingsProvider.settings).thenReturn(settings);

    // Case 1: Disabled in SystemConfigProvider
    var systemConfigs = SystemConfigsModel(
      lifetimePlanEnabled: false,
      remainingLifetimeSeats: 10,
    );
    when(() => mockConfigProvider.configs).thenReturn(systemConfigs);

    await tester.pumpWidget(buildTestableWidget(const PaywallScreen()));

    expect(find.text('Lifetime VIP Plan'), findsNothing);

    // Case 2: Enabled but sold out (0 seats)
    systemConfigs = SystemConfigsModel(
      lifetimePlanEnabled: true,
      remainingLifetimeSeats: 0,
    );
    when(() => mockConfigProvider.configs).thenReturn(systemConfigs);

    await tester.pumpWidget(buildTestableWidget(const PaywallScreen()));

    expect(find.text('Lifetime VIP Plan'), findsOneWidget);
    expect(find.text('Sold Out'), findsOneWidget);
  });
}
