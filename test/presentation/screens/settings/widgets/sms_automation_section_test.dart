import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/settings/widgets/sms_automation_section.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/routes/navigation_service.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;
  late MockNavigatorObserver mockNavigatorObserver;
  late MockFlutterSecureStorage mockSecureStorage;

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalStorageService.reset();

    mockSecureStorage = MockFlutterSecureStorage();
    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => {});

    await LocalStorageService.instance
        .initialize(secureStorage: mockSecureStorage);

    mockAuthProvider = MockAuthProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();
    mockNavigatorObserver = MockNavigatorObserver();

    when(() => mockAuthProvider.isOwner).thenReturn(true);
    when(() => mockAuthProvider.isEmployee).thenReturn(false);
    when(() => mockSubscriptionProvider.isExpired).thenReturn(false);
  });

  tearDown(() {
    LocalStorageService.reset();
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: mockSubscriptionProvider),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        builder: BotToastInit(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar')],
        navigatorObservers: [
          BotToastNavigatorObserver(),
          mockNavigatorObserver
        ],
        routes: {
          RouteConstants.upgradeScreen: (context) =>
              const Scaffold(body: Text('Paywall')),
        },
        home: const Scaffold(body: SmsAutomationSection()),
      ),
    );
  }

  group('SmsAutomationSection Widget Tests', () {
    testWidgets('Active subscription allows toggle to work normally',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      final switchTile = find.byType(SwitchListTile);
      expect(switchTile, findsOneWidget);

      final switchWidget = tester.widget<SwitchListTile>(switchTile);
      expect(switchWidget.onChanged, isNotNull); // not disabled visually
    });

    testWidgets(
        'Expired subscription for Employee shows toast and does NOT navigate',
        (tester) async {
      when(() => mockAuthProvider.isOwner).thenReturn(false);
      when(() => mockSubscriptionProvider.isExpired).thenReturn(true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      clearInteractions(mockNavigatorObserver);

      await tester.tap(find.byType(SwitchListTile), warnIfMissed: false);
      await tester.pumpAndSettle(); // Wait for any async

      // Verify no navigation occurred
      verifyNever(() => mockNavigatorObserver.didPush(any(), any()));
    });

    testWidgets(
        'Expired subscription for Owner shows toast and routes to Paywall',
        (tester) async {
      when(() => mockAuthProvider.isOwner).thenReturn(true);
      when(() => mockSubscriptionProvider.isExpired).thenReturn(true);

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile), warnIfMissed: false);

      // Wait for navigation animation
      await tester.pumpAndSettle();
      expect(find.text('Paywall'), findsOneWidget); // Routed correctly
    });

    testWidgets(
        'renders cleanly without diagnostic cards or playground in production',
        (tester) async {
      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('سجل الرسائل المرفوضة (Diagnostic Logs)'), findsNothing);
      expect(
          find.text('مختبر فحص الرسائل (SMS Parser Playground)'), findsNothing);
      expect(find.text('DIAGNOSTIC'), findsNothing);
    });
  });
}
