import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/home/widgets/dashboard_quick_stats.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get currentUser => UserModel(
        userId: 'owner_1',
        fullName: 'Owner Name',
        role: UserRole.owner,
        storeId: 'store_123',
      );
  @override
  String? get currentStoreId => 'store_123';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStatisticsProvider extends ChangeNotifier implements StatisticsProvider {
  @override
  bool get isLoading => false;
  @override
  StatsSummaryModel? get dashboardSummary => StatsSummaryModel(
        totalWallets: 3,
        totalBalance: 1500.0,
        openDebtsCount: 2,
        totalTransactions: 10,
        totalCommission: 50.0,
        receiveCount: 3,
        sendCount: 4,
        totalReceivedAmount: 1000.0,
        totalSentAmount: 2000.0,
        paidDebtsCount: 1,
        totalOpenAmount: 300.0,
        totalPaidAmount: 100.0,
      );
  @override
  DailyStatsModel? get todayStats => DailyStatsModel(
        date: '2026-07-12',
        totalTransactions: 5,
        totalCommission: 15.0,
      );
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTransactionProvider extends ChangeNotifier implements TransactionProvider {
  final List<TransactionModel> _todayTxns;
  MockTransactionProvider(this._todayTxns);

  @override
  List<TransactionModel> get todayTransactions => _todayTxns;

  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('DashboardQuickStats Total Transactions card shows only transfer (debit) transactions count',
      (WidgetTester tester) async {
    // 1 debit (transfer), 1 credit (receive), 1 deposit (top-up)
    final mockTxns = [
      TransactionModel(
        transactionId: 't1',
        storeId: 'store_123',
        walletId: 'w1',
        transactionType: TransactionType.debit, // Transfer
        amount: 100.0,
        createdBy: 'user1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      TransactionModel(
        transactionId: 't2',
        storeId: 'store_123',
        walletId: 'w1',
        transactionType: TransactionType.credit, // Receive
        amount: 200.0,
        createdBy: 'user1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
      TransactionModel(
        transactionId: 't3',
        storeId: 'store_123',
        walletId: 'w1',
        transactionType: TransactionType.deposit, // Top-up
        amount: 300.0,
        createdBy: 'user1',
        transactionDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    ];

    final authProvider = MockAuthProvider();
    final statsProvider = MockStatisticsProvider();
    final txProvider = MockTransactionProvider(mockTxns);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<StatisticsProvider>.value(value: statsProvider),
          ChangeNotifierProvider<TransactionProvider>.value(value: txProvider),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                DashboardQuickStats(),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // The 'Total Transactions' card value should show 1 (only the debit/transfer transaction)
    // and not the generic provider.todayStats?.totalTransactions which is 5.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('5'), findsNothing);
  });
}
