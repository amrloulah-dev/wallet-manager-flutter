import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walletmanager/presentation/widgets/wallet/wallet_card.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  late WalletModel activeWallet;
  late WalletModel frozenWallet;

  setUp(() {
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
    return MaterialApp(
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

  testWidgets('WalletCard displays status correctly when frozen',
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

    // Verify "غير نشطة" badge is displayed
    expect(find.text('غير نشطة'), findsOneWidget);
  });
}
