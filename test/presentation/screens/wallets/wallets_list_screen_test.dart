import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/wallets/wallets_list_screen.dart';
import 'package:walletmanager/presentation/widgets/wallet/wallet_card.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockWalletProvider extends Mock implements WalletProvider {
  @override
  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {}
}

class MockPlatformSettingsProvider extends Mock implements PlatformSettingsProvider {}

class FakeWalletModel extends Fake implements WalletModel {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockWalletProvider mockWalletProvider;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUpAll(() {
    registerFallbackValue(FakeWalletModel());
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockWalletProvider = MockWalletProvider();
    mockSettingsProvider = MockPlatformSettingsProvider();

    when(() => mockSettingsProvider.settings).thenReturn(const PlatformSettingsModel.defaults());

    when(() => mockAuthProvider.isSubscriptionExpired).thenReturn(true);
    when(() => mockWalletProvider.isLoading).thenReturn(false);
    when(() => mockWalletProvider.isLoadingMore).thenReturn(false);
    when(() => mockWalletProvider.hasError).thenReturn(false);
    when(() => mockWalletProvider.errorMessage).thenReturn(null);
    when(() => mockWalletProvider.isWalletFrozenSync(any())).thenReturn(false);
    when(() => mockWalletProvider.wallets).thenReturn([
      WalletModel(
        walletId: 'w1',
        phoneNumber: '01000000000',
        walletType: WalletType.vodafoneCash,
        walletStatus: WalletStatus.active,
        balance: 100,
        storeId: 'store_1',
        createdBy: 'owner_1',
        sendLimits: WalletLimits(dailyLimit: 30000, monthlyLimit: 100000),
        receiveLimits: WalletLimits(dailyLimit: 30000, monthlyLimit: 100000),
        stats: WalletStats(),
      )
    ]);
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
        ChangeNotifierProvider<PlatformSettingsProvider>.value(value: mockSettingsProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const WalletsListScreen(),
      ),
    );
  }

  testWidgets(
      'Wallets list edit and delete actions block when subscription expired',
      (tester) async {
    when(() => mockAuthProvider.isSubscriptionExpired).thenReturn(true);

    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify wallet is rendered
    expect(find.byType(WalletCard), findsOneWidget);

    // Tap Edit
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pump();

    // Tap Delete
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    // Since it's blocked, deleteWallet should never be called
    verifyNever(() => mockWalletProvider.deleteWallet(any()));
  });

  testWidgets(
      'Wallets list screen shows a simple FloatingActionButton.extended for adding a wallet',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify FloatingActionButton.extended is present with label and icon
    final fabFinder = find.byType(FloatingActionButton);
    expect(fabFinder, findsOneWidget);

    final fabTextFinder = find.text('Add Wallet');
    expect(fabTextFinder, findsOneWidget);

    final iconFinder = find.byIcon(Icons.add);
    expect(iconFinder, findsOneWidget);
  });
}
