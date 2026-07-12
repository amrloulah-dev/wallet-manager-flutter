import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/screens/settings/settings_screen.dart';
import 'package:walletmanager/presentation/screens/settings/widgets/app_settings_section.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/theme_provider.dart';
import 'package:walletmanager/providers/localization_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}

class MockThemeProvider extends Mock implements ThemeProvider {}

class MockLocalizationProvider extends Mock implements LocalizationProvider {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubProvider;
  late MockThemeProvider mockThemeProvider;
  late MockLocalizationProvider mockLocProvider;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubProvider = MockSubscriptionProvider();
    mockThemeProvider = MockThemeProvider();
    mockLocProvider = MockLocalizationProvider();
    mockSettingsProvider = MockPlatformSettingsProvider();

    // Default stubs
    final now = DateTime.now();
    when(() => mockAuthProvider.currentUser).thenReturn(
      UserModel(
        userId: 'test_user',
        storeId: 'test_store',
        role: UserRole.owner, // ENUM refactor
        fullName: 'Test User',
        email: 'test@example.com',
        phone: '123456789',
        isActive: true,
        createdAt: now,
        lastLogin: now,
      ),
    );
    when(() => mockAuthProvider.currentStore).thenReturn(
      StoreModel(
        storeId: 'test_store',
        storeName: 'Test Store',
        storePassword: 'hashed_password',
        ownerId: 'test_user',
        ownerName: 'Test User',
        ownerEmail: 'test@example.com',
        createdAt: now,
        subscription: StoreSubscription(
          planId: SubscriptionPlan.trial, // ENUM refactor
          status: SubscriptionStatus.active, // ENUM refactor
          trialConsumed: false,
        ),
        settings: StoreSettings(
          currency: 'USD',
          timezone: 'UTC',
        ),
      ),
    );
    when(() => mockAuthProvider.isTrial).thenReturn(true);
    when(() => mockAuthProvider.trialDaysRemaining).thenReturn(7);
    when(() => mockAuthProvider.isOwner).thenReturn(true);
    when(() => mockAuthProvider.isEmployee).thenReturn(false);

    when(() => mockSubProvider.isExpired).thenReturn(false);
    when(() => mockSubProvider.daysRemaining).thenReturn(7);

    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);

    when(() => mockLocProvider.locale).thenReturn(const Locale('en'));
    when(() => mockLocProvider.isArabic).thenReturn(false);

    when(() => mockSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());
    when(() => mockSettingsProvider.forceRefresh()).thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(
            value: mockSubProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<LocalizationProvider>.value(
            value: mockLocProvider),
        ChangeNotifierProvider<PlatformSettingsProvider>.value(
            value: mockSettingsProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen displays basic structure',
      (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify it renders without crashing
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  Widget createAppSettingsSectionUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<LocalizationProvider>.value(
            value: mockLocProvider),
        ChangeNotifierProvider<PlatformSettingsProvider>.value(
            value: mockSettingsProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(
          body: AppSettingsSection(),
        ),
      ),
    );
  }

  testWidgets(
      'AppSettingsSection displays Refresh Platform Settings tile and tapping triggers forceRefresh',
      (WidgetTester tester) async {
    final completer = Completer<void>();
    when(() => mockSettingsProvider.forceRefresh())
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(createAppSettingsSectionUnderTest());
    await tester.pumpAndSettle();

    // Find the refresh tile
    final refreshTileFinder = find.text('Refresh Platform Settings');
    expect(refreshTileFinder, findsOneWidget);

    // Tap the refresh tile
    await tester.tap(refreshTileFinder);
    await tester.pump();

    // Verify loading spinner is shown
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Complete the forceRefresh Future
    completer.complete();
    await tester.pumpAndSettle();

    // Verify forceRefresh is called
    verify(() => mockSettingsProvider.forceRefresh()).called(1);

    // Verify success snackbar is shown
    expect(
        find.text('Platform settings refreshed successfully'), findsOneWidget);
  });

  testWidgets('AppSettingsSection shows error SnackBar when forceRefresh fails',
      (WidgetTester tester) async {
    when(() => mockSettingsProvider.forceRefresh())
        .thenThrow(Exception('Firestore error'));

    await tester.pumpWidget(createAppSettingsSectionUnderTest());
    await tester.pumpAndSettle();

    final refreshTileFinder = find.text('Refresh Platform Settings');
    await tester.tap(refreshTileFinder);
    await tester.pumpAndSettle();

    // Verify error snackbar is shown
    expect(find.text('Failed to refresh platform settings'), findsOneWidget);
  });
}
