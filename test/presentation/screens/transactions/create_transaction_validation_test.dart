import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:get_it/get_it.dart';
import 'package:walletmanager/presentation/screens/transactions/create_transaction_screen.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/domain/usecases/transaction_fee_calculator.dart';
import 'package:walletmanager/data/models/platform_settings_model.dart';
import 'package:walletmanager/presentation/widgets/common/custom_dropdown.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockWalletProvider extends Mock implements WalletProvider {}

class MockTransactionProvider extends Mock implements TransactionProvider {}

class MockPlatformSettingsProvider extends Mock
    implements PlatformSettingsProvider {}

void main() {
  final sl = GetIt.instance;

  late MockWalletProvider mockWalletProvider;
  late MockTransactionProvider mockTransactionProvider;
  late MockPlatformSettingsProvider mockPlatformSettingsProvider;

  setUpAll(() {
    if (!sl.isRegistered<TransactionFeeCalculator>()) {
      sl.registerLazySingleton<TransactionFeeCalculator>(
          () => TransactionFeeCalculator());
    }
  });

  setUp(() {
    mockWalletProvider = MockWalletProvider();
    mockTransactionProvider = MockTransactionProvider();
    mockPlatformSettingsProvider = MockPlatformSettingsProvider();

    // Default stubbing
    when(() => mockWalletProvider.isLoading).thenReturn(false);
    when(() => mockWalletProvider.fetchInitialWallets())
        .thenAnswer((_) async {});

    when(() => mockTransactionProvider.isCreating).thenReturn(false);
    when(() => mockTransactionProvider.errorMessage).thenReturn(null);
    when(() => mockTransactionProvider.hasError).thenReturn(false);

    when(() => mockPlatformSettingsProvider.settings)
        .thenReturn(const PlatformSettingsModel.defaults());

    final telecomWallet = WalletModel(
      walletId: 'telecom_1',
      storeId: 'store_123',
      phoneNumber: '01012345678',
      walletType: WalletType.vodafoneCash,
      walletStatus: WalletStatus.active,
      balance: 1000.0,
      createdBy: 'user_123',
      sendLimits: WalletLimits(
        dailyLimit: 30000.0,
        dailyUsed: 0.0,
        monthlyLimit: 100000.0,
        monthlyUsed: 0.0,
      ),
      receiveLimits: WalletLimits(
        dailyLimit: 10000.0, // dailyRemaining = 10000.0
        dailyUsed: 0.0,
        monthlyLimit: 50000.0, // monthlyRemaining = 50000.0
        monthlyUsed: 0.0,
      ),
      stats: WalletStats(
        totalTransactions: 0,
        totalCommission: 0.0,
        totalSentAmount: 0.0,
        totalReceivedAmount: 0.0,
      ),
    );

    final instapayWallet = WalletModel(
      walletId: 'instapay_1',
      storeId: 'store_123',
      phoneNumber: '01087654321',
      walletType: WalletType.instaPay,
      walletStatus: WalletStatus.active,
      balance: 2000.0,
      createdBy: 'user_123',
      sendLimits: WalletLimits(
        dailyLimit: 70000.0,
        dailyUsed: 0.0,
        monthlyLimit: 200000.0,
        monthlyUsed: 0.0,
      ),
      receiveLimits: WalletLimits(
        dailyLimit: 50000.0, // dailyRemaining = 50000.0
        dailyUsed: 0.0,
        monthlyLimit: 100000.0, // monthlyRemaining = 100000.0
        monthlyUsed: 0.0,
      ),
      stats: WalletStats(
        totalTransactions: 0,
        totalCommission: 0.0,
        totalSentAmount: 0.0,
        totalReceivedAmount: 0.0,
      ),
    );

    final walletsList = [telecomWallet, instapayWallet];
    final walletsMap = {
      'telecom_1': telecomWallet,
      'instapay_1': instapayWallet,
    };

    when(() => mockWalletProvider.wallets).thenReturn(walletsList);
    when(() => mockWalletProvider.walletMap).thenReturn(walletsMap);
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: mockWalletProvider),
        ChangeNotifierProvider<TransactionProvider>.value(
            value: mockTransactionProvider),
        ChangeNotifierProvider<PlatformSettingsProvider>.value(
            value: mockPlatformSettingsProvider),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ar')],
        locale: Locale('ar'), // Arabic to test specific messages & UI
        home: CreateTransactionScreen(),
      ),
    );
  }

  testWidgets(
      'Amount field border and validation error behavior on telecom Receive',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Select the telecom wallet
    final dropdownFinder = find.byType(CustomDropdown<WalletModel>);
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Select Vodafone Cash option
    final optionFinder = find.textContaining('فودافون كاش').last;
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();

    // Select Receive transaction type (credit)
    final receiveButtonFinder = find.text('استلام');
    await tester.tap(receiveButtonFinder);
    await tester.pumpAndSettle();

    // Find the amount field
    final amountFieldFinder = find.widgetWithText(CustomTextField, 'المبلغ');
    expect(amountFieldFinder, findsOneWidget);

    // Enter amount within limit (e.g. 500)
    await tester.enterText(
        find.descendant(
            of: amountFieldFinder, matching: find.byType(TextField)),
        '500');
    await tester.pumpAndSettle();

    // Validate that normal style is maintained, and submit button is enabled
    final submitButtonFinder =
        find.widgetWithText(CustomButton, 'إنشاء المعاملة');
    expect(submitButtonFinder, findsOneWidget);
    final submitButton = tester.widget<CustomButton>(submitButtonFinder);
    // Submit button should be enabled (onPressed is not null)
    expect(submitButton.onPressed, isNotNull);

    // Enter amount exceeding daily limit (maxAvailable is min(10000, 49000) = 10000)
    // 12000 exceeds 10000 (daily limit)
    await tester.enterText(
        find.descendant(
            of: amountFieldFinder, matching: find.byType(TextField)),
        '12000');
    await tester.pumpAndSettle();

    // Submit button should be disabled for telecom wallet
    final submitButtonDisabled =
        tester.widget<CustomButton>(submitButtonFinder);
    expect(submitButtonDisabled.onPressed, isNull);

    // Check error text is visible (daily limit exceeded message: "يتجاوز الحد اليومي")
    expect(find.text('يتجاوز الحد اليومي'), findsOneWidget);
  });

  testWidgets('Amount field warning behavior on InstaPay Receive',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Select the InstaPay wallet
    final dropdownFinder = find.byType(CustomDropdown<WalletModel>);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Select InstaPay option
    final optionFinder = find.textContaining('إنستاباي').last;
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();

    // Select Receive transaction type (credit)
    final receiveButtonFinder = find.text('استلام');
    await tester.tap(receiveButtonFinder);
    await tester.pumpAndSettle();

    final amountFieldFinder = find.widgetWithText(CustomTextField, 'المبلغ');

    // Enter amount exceeding limit (maxAvailable is 50000. Enter 60000)
    await tester.enterText(
        find.descendant(
            of: amountFieldFinder, matching: find.byType(TextField)),
        '60000');
    await tester.pumpAndSettle();

    // Submit button should remain enabled (soft warning only)
    final submitButtonFinder =
        find.widgetWithText(CustomButton, 'إنشاء المعاملة');
    final submitButton = tester.widget<CustomButton>(submitButtonFinder);
    expect(submitButton.onPressed, isNotNull);

    // Check warning text is visible ("يتجاوز الحد اليومي")
    expect(find.text('يتجاوز الحد اليومي'), findsOneWidget);
  });

  testWidgets('Max button auto-populates maxAvailable and triggers validation',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Select the telecom wallet (Vodafone Cash, maxAvailable = 10000)
    final dropdownFinder = find.byType(CustomDropdown<WalletModel>);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    final optionFinder = find.textContaining('فودافون كاش').last;
    await tester.tap(optionFinder);
    await tester.pumpAndSettle();

    // Select Receive type
    final receiveButtonFinder = find.text('استلام');
    await tester.tap(receiveButtonFinder);
    await tester.pumpAndSettle();

    // Max button should be visible (IconButton with arrow up icon)
    final maxButtonFinder = find.byIcon(Icons.keyboard_double_arrow_up_rounded);
    expect(maxButtonFinder, findsOneWidget);

    // Tap Max button
    await tester.tap(maxButtonFinder);
    await tester.pumpAndSettle();

    // Amount text field should now contain '10000.0' or '10000'
    final textField = tester.widget<TextField>(find.descendant(
      of: find.widgetWithText(CustomTextField, 'المبلغ'),
      matching: find.byType(TextField),
    ));
    expect(double.parse(textField.controller!.text), 10000.0);

    // Error text should not be shown because 10000 is exactly equal to maxAvailable
    expect(find.text('يتجاوز الحد اليومي'), findsNothing);
  });
}
