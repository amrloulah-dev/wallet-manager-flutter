import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/transactions/today_transactions_screen.dart';
import 'package:walletmanager/presentation/widgets/transaction/transaction_card.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class MockAuthProvider extends Mock implements AuthProvider {}

class MockTransactionProvider extends Mock implements TransactionProvider {
  @override
  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {}
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class FakeRoute extends Fake implements Route {}

void main() {
  late MockAuthProvider mockAuthProvider;
  late MockTransactionProvider mockTransactionProvider;
  late MockNavigatorObserver mockNavigatorObserver;

  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockTransactionProvider = MockTransactionProvider();
    mockNavigatorObserver = MockNavigatorObserver();

    when(() => mockTransactionProvider.status)
        .thenReturn(TransactionProviderStatus.loaded);
    when(() => mockTransactionProvider.errorMessage).thenReturn(null);
    when(() => mockTransactionProvider.filterType).thenReturn(null);
    when(() => mockTransactionProvider.hasMore).thenReturn(false);
    when(() => mockTransactionProvider.summary).thenReturn({
      'totalTransactions': 2,
      'sendCount': 1,
      'receiveCount': 1,
      'totalSendAmount': 100.0,
      'totalReceiveAmount': 50.0,
      'totalCommission': 5.0,
    });

    final now = DateTime.now();
    final mockTxList = [
      TransactionModel(
        transactionId: 'tx_credit',
        storeId: 'store_123',
        walletId: 'w1',
        transactionType: TransactionType.credit,
        customerPhone: '01000000000',
        amount: 50.0,
        commission: 2.0,
        serviceFee: 0.5,
        paymentStatus: PaymentStatus.paid,
        transactionDate: now,
        createdAt: now,
        createdBy: 'test',
        createdById: 'owner',
      ),
      TransactionModel(
        transactionId: 'tx_debit',
        storeId: 'store_123',
        walletId: 'w1',
        transactionType: TransactionType.debit,
        customerPhone: '01000000000',
        amount: 100.0,
        commission: 3.0,
        serviceFee: 0.5,
        paymentStatus: PaymentStatus.paid,
        transactionDate: now,
        createdAt: now,
        createdBy: 'test',
        createdById: 'owner',
      ),
      TransactionModel(
        transactionId: 'tx_deposit',
        storeId: 'store_123',
        walletId: 'w1',
        transactionType: TransactionType.deposit,
        customerPhone: '01000000000',
        amount: 500.0,
        commission: 0.0,
        serviceFee: 0.0,
        paymentStatus: PaymentStatus.paid,
        transactionDate: now,
        createdAt: now,
        createdBy: 'test',
        createdById: 'owner',
      ),
    ];

    when(() => mockTransactionProvider.transactions).thenReturn(mockTxList);
  });

  Widget buildTestableWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<TransactionProvider>.value(
            value: mockTransactionProvider),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en')],
        home: const TodayTransactionsScreen(),
        navigatorObservers: [mockNavigatorObserver],
      ),
    );
  }

  testWidgets(
      'TodayTransactionsScreen filters transactions and only displays credit/debit types',
      (tester) async {
    await tester.pumpWidget(buildTestableWidget());
    await tester.pumpAndSettle();

    // Verify transaction list only contains the debit and credit cards
    expect(find.byType(TransactionCard), findsNWidgets(2));

    // Verify deposit card is NOT rendered
    expect(find.text('tx_deposit'), findsNothing);
  });
}
