import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:walletmanager/presentation/widgets/wallet/wallet_card.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  late WalletModel activeWallet;
  late WalletModel frozenWallet;
  late MockPlatformSettingsProvider mockSettingsProvider;

  setUp(() {
    mockSettingsProvider = MockPlatformSettingsProvider();
    when(() => mockSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());
    activeWallet = WalletModel(
      walletId: 'w1',
      phoneNumber: '01168686098',
      walletType: WalletType.instaPay,
      walletStatus: WalletStatus.active,
      balance: 1612.00,
      storeId: 'store_1',
      createdBy: 'owner_1',
      sendLimits: WalletLimits(dailyLimit: 120000, monthlyLimit: 100000),
      receiveLimits: WalletLimits(dailyLimit: 120000, monthlyLimit: 100000),
      stats: WalletStats(
        totalTransactions: 0,
        totalCommission: 0,
      ),
    );

    frozenWallet = WalletModel(
      walletId: 'w2',
      phoneNumber: '01168686098',
      walletType: WalletType.instaPay,
      walletStatus: WalletStatus.active,
      balance: 1612.00,
      storeId: 'store_1',
      createdBy: 'owner_1',
      sendLimits: WalletLimits(dailyLimit: 120000, monthlyLimit: 100000),
      receiveLimits: WalletLimits(dailyLimit: 120000, monthlyLimit: 100000),
      stats: WalletStats(
        totalTransactions: 0,
        totalCommission: 0,
      ),
    );
  });

  Widget buildTestableWidget(Widget child) {
    return ChangeNotifierProvider<PlatformSettingsProvider>.value(
      value: mockSettingsProvider,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: const Locale('ar'), // Set to Arabic to match Stitch specs
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'WalletCard renders wallet phone, type and balance in Arabic locale',
      (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        WalletCard(
          wallet: activeWallet,
          isFrozen: false,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify phone number is shown
    expect(
        find.text(NumberFormatter.formatPhoneNumber(activeWallet.phoneNumber)),
        findsOneWidget);

    // Verify provider name is rendered in Arabic
    expect(find.text('إنستاباي'), findsOneWidget);

    // Verify balance is rendered in English numbers (per project limits)
    expect(
        find.textContaining(NumberFormatter.formatAmount(activeWallet.balance)),
        findsOneWidget);
  });

  testWidgets(
      'WalletCard triggers callbacks when edit and delete buttons are tapped',
      (tester) async {
    bool editTapped = false;
    bool deleteTapped = false;

    await tester.pumpWidget(
      buildTestableWidget(
        WalletCard(
          wallet: activeWallet,
          isFrozen: false,
          onTap: () {},
          onEdit: () => editTapped = true,
          onDelete: () => deleteTapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap delete button (labeled "حذف")
    final deleteButton = find.text('حذف');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(deleteTapped, isTrue);

    // Tap edit button (labeled "تعديل")
    final editButton = find.text('تعديل');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();
    expect(editTapped, isTrue);
  });

  testWidgets('WalletCard displays status correctly when frozen (but active)',
      (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        WalletCard(
          wallet: frozenWallet,
          isFrozen: true,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "قديمة" badge is NOT displayed, and "جديدة" is displayed instead
    expect(find.text('قديمة'), findsNothing);
    expect(find.text('جديدة'), findsOneWidget);
  });

  testWidgets('WalletCard displays status correctly when suspended',
      (tester) async {
    final suspendedWallet = WalletModel(
      walletId: 'w3',
      phoneNumber: '01168686098',
      walletType: WalletType.instaPay,
      walletStatus: WalletStatus.suspended,
      balance: 1612.00,
      storeId: 'store_1',
      createdBy: 'owner_1',
      sendLimits: WalletLimits(dailyLimit: 120000, monthlyLimit: 100000),
      receiveLimits: WalletLimits(dailyLimit: 120000, monthlyLimit: 100000),
      stats: WalletStats(
        totalTransactions: 0,
        totalCommission: 0,
      ),
    );

    await tester.pumpWidget(
      buildTestableWidget(
        WalletCard(
          wallet: suspendedWallet,
          isFrozen: false,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify "محل مسجل" badge is displayed
    expect(find.text('محل مسجل'), findsOneWidget);
  });

  testWidgets(
      'WalletCard currentBalance text has TextOverflow.ellipsis to prevent overflow',
      (tester) async {
    await tester.pumpWidget(
      buildTestableWidget(
        WalletCard(
          wallet: activeWallet,
          isFrozen: false,
          onTap: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Text currentBalanceText =
        tester.widget<Text>(find.text('الرصيد الحالي'));
    expect(currentBalanceText.overflow, equals(TextOverflow.ellipsis));
  });
}
