import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/screens/settings/settings_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/theme_provider.dart';
import 'package:walletmanager/providers/localization_provider.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';


class MockAuthProvider extends Mock implements AuthProvider {}
class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}
class MockThemeProvider extends Mock implements ThemeProvider {}
class MockLocalizationProvider extends Mock implements LocalizationProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockSubscriptionProvider mockSubProvider;
  late MockThemeProvider mockThemeProvider;
  late MockLocalizationProvider mockLocProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockSubProvider = MockSubscriptionProvider();
    mockThemeProvider = MockThemeProvider();
    mockLocProvider = MockLocalizationProvider();

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
          maxWallets: 5,
          maxEmployees: 2,
          smsEnabled: true,
        ),
        settings: StoreSettings(
          currency: 'USD',
          timezone: 'UTC',
        ),
        stats: StoreStats(
          totalWallets: 0,
          activeWallets: 0,
          totalTransactionsToday: 0,
          totalCommissionToday: 0.0,
          lastUpdated: now,
        ),
      ),
    );
    when(() => mockAuthProvider.isTrial).thenReturn(true);
    when(() => mockAuthProvider.trialDaysRemaining).thenReturn(7);
    
    when(() => mockSubProvider.isExpired).thenReturn(false);
    when(() => mockSubProvider.daysRemaining).thenReturn(7);
    
    when(() => mockThemeProvider.themeMode).thenReturn(ThemeMode.light);
    
    when(() => mockLocProvider.locale).thenReturn(const Locale('en'));
    when(() => mockLocProvider.isArabic).thenReturn(false);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: mockSubProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: mockThemeProvider),
        ChangeNotifierProvider<LocalizationProvider>.value(value: mockLocProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen displays basic structure', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify it renders without crashing
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
