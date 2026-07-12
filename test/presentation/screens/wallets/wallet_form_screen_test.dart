import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/wallets/wallet_form_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}
class MockWalletProvider extends Mock implements WalletProvider {}
class MockSubscriptionProvider extends Mock implements SubscriptionProvider {}
class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockWalletProvider mockWalletProvider;
  late MockSubscriptionProvider mockSubscriptionProvider;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();
    mockSubscriptionProvider = MockSubscriptionProvider();
    mockSettingsProvider = MockPlatformSettingsProvider();

    when(() => mockSettingsProvider.settings).thenReturn(const PlatformSettingsModel.defaults());
    when(() => mockWalletProvider.isLoading).thenReturn(false);
    when(() => mockWalletProvider.isCreating).thenReturn(false);
    when(() => mockWalletProvider.isUpdating).thenReturn(false);
    when(() => mockWalletProvider.hasError).thenReturn(false);
    when(() => mockWalletProvider.errorMessage).thenReturn(null);
    when(() => mockWalletProvider.wallets).thenReturn([]);
    when(() => mockAuthProvider.currentUserId).thenReturn('user_123');
  });

  Widget buildTestableWidget({Locale locale = const Locale('ar')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
        ChangeNotifierProvider<SubscriptionProvider>.value(value: mockSubscriptionProvider),
        ChangeNotifierProvider<PlatformSettingsProvider>.value(value: mockSettingsProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: locale,
        home: const WalletFormScreen(),
      ),
    );
  }

  testWidgets(
      'WalletFormScreen status dropdown displays correct active/inactive Arabic labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    // Find the status dropdown field. CustomDropdown lists statusDisplayNames.
    // In Arabic locale, let's tap the dropdown to show choices.
    final dropdownFinder = find.byType(DropdownButtonFormField<WalletStatus>);
    expect(dropdownFinder, findsOneWidget);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Verify "نشطة" (active) and "غير نشطة" (inactive) labels are displayed in the dropdown popup
    // Since "نشطة" is active and "غير نشطة" is inactive.
    expect(find.text('نشطة'), findsWidgets);
    expect(find.text('غير نشطة'), findsWidgets);
  });
}
