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
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
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

  setUpAll(() {
    registerFallbackValue(WalletType.vodafoneCash);
    registerFallbackValue(WalletStatus.active);
  });

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

  Widget buildTestableWidget({Locale locale = const Locale('ar'), WalletModel? walletToEdit}) {
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
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: RouteSettings(arguments: walletToEdit),
            builder: (context) => const WalletFormScreen(),
          );
        },
      ),
    );
  }

  testWidgets(
      'WalletFormScreen status dropdown displays correct active/inactive Arabic labels',
      (WidgetTester tester) async {
    await tester.pumpWidget(buildTestableWidget(locale: const Locale('ar')));
    await tester.pumpAndSettle();

    // Find the status dropdown field
    final dropdownFinder = find.byType(DropdownButtonFormField<WalletStatus>);
    expect(dropdownFinder, findsOneWidget);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Verify "نشطة" (active) and "غير نشطة" (inactive) labels are displayed in the dropdown popup
    expect(find.text('نشطة'), findsWidgets);
    expect(find.text('غير نشطة'), findsWidgets);
  });

  testWidgets(
      'WalletFormScreen validates phone number carrier prefix on submission',
      (WidgetTester tester) async {
    // Inject limits so create checks pass
    when(() => mockSubscriptionProvider.canAddWallet(any())).thenReturn(true);
    when(() => mockWalletProvider.createWallet(
          phoneNumber: any(named: 'phoneNumber'),
          walletType: any(named: 'walletType'),
          walletStatus: any(named: 'walletStatus'),
          balance: any(named: 'balance'),
          notes: any(named: 'notes'),
          createdBy: any(named: 'createdBy'),
        )).thenAnswer((_) async => true);

    await tester.pumpWidget(buildTestableWidget(locale: const Locale('en')));
    await tester.pumpAndSettle();

    // Find fields
    final phoneFinder = find.byType(TextField).at(0); // Phone field
    final balanceFinder = find.byType(TextField).at(1); // Balance field

    // Enter a number with 010 (Vodafone) prefix but we will choose Etisalat Cash type
    await tester.enterText(phoneFinder, '01012345678');
    await tester.enterText(balanceFinder, '100');
    await tester.pumpAndSettle();

    // Select Etisalat Cash dropdown
    final typeDropdownFinder = find.byType(DropdownButtonFormField<WalletType>);
    await tester.tap(typeDropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Etisalat Cash').last);
    await tester.pumpAndSettle();

    // Select Active status dropdown
    final statusDropdownFinder = find.byType(DropdownButtonFormField<WalletStatus>);
    await tester.tap(statusDropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Active').last);
    await tester.pumpAndSettle();

    // Try submitting
    final saveBtnFinder = find.byType(ElevatedButton);
    await tester.ensureVisible(saveBtnFinder);
    await tester.tap(saveBtnFinder);
    await tester.pumpAndSettle();

    // Verify warning dialog is displayed
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);

    // Tap "Confirm Anyway"
    await tester.tap(find.text('Confirm Anyway'));
    await tester.pumpAndSettle();

    // Verify dialog closed and createWallet was called
    verify(() => mockWalletProvider.createWallet(
          phoneNumber: '01012345678',
          walletType: WalletType.etisalatCash,
          walletStatus: WalletStatus.active,
          balance: 100.0,
          notes: '',
          createdBy: 'user_123',
        )).called(1);
  });

  testWidgets(
      'WalletFormScreen preserves existing carrier when editing an existing wallet',
      (WidgetTester tester) async {
    final editWallet = WalletModel(
      walletId: 'w1',
      phoneNumber: '01012345678', // Vodafone prefix
      walletType: WalletType.vodafoneCash,
      walletStatus: WalletStatus.active,
      balance: 1000,
      storeId: 'store_123',
      createdBy: 'user_123',
      sendLimits: WalletLimits(dailyLimit: 30000, monthlyLimit: 100000),
      receiveLimits: WalletLimits(dailyLimit: 30000, monthlyLimit: 100000),
      stats: WalletStats(),
    );

    when(() => mockWalletProvider.updateWallet(any(), any())).thenAnswer((_) async => true);

    await tester.pumpWidget(buildTestableWidget(locale: const Locale('en'), walletToEdit: editWallet));
    await tester.pumpAndSettle();

    // Find notes field
    final notesFinder = find.byIcon(Icons.note_alt_outlined);
    expect(notesFinder, findsOneWidget);

    // Find CustomTextField for notes
    final notesTextFieldFinder = find.ancestor(of: notesFinder, matching: find.byType(TextField));
    await tester.enterText(notesTextFieldFinder, 'Preserve carrier test');
    await tester.pumpAndSettle();

    // Save changes
    final saveBtnFinder = find.byType(ElevatedButton);
    await tester.ensureVisible(saveBtnFinder);
    await tester.tap(saveBtnFinder);
    await tester.pumpAndSettle();

    // Verify updateWallet called with correct carrier type
    verify(() => mockWalletProvider.updateWallet(
          'w1',
          {
            'walletType': 'vodafoneCash',
            'notes': 'Preserve carrier test',
          },
        )).called(1);
  });
}
