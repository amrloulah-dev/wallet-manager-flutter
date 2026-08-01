import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/presentation/screens/home/main_dashboard_screen.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/subscription_provider.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/data/models/subscription_request_model.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';

class DummyAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  String? get currentStoreId => 'store_123';
  @override
  StoreModel? get currentStore => null;
  @override
  UserModel? get currentUser => null;
  @override
  bool get isTrial => true;
  @override
  int? get trialDaysRemaining => 14;
  @override
  bool get isOwner => true;
  @override
  bool get isEmployee => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummySubscriptionProvider extends ChangeNotifier
    implements SubscriptionProvider {
  @override
  bool get hasSeenSuccessModal => true;
  @override
  bool get hasDismissedRejection => true;
  @override
  bool get isSuspended => false;
  @override
  bool get isExpired => false;
  @override
  int? get daysRemaining => 14;
  @override
  SubscriptionRequestModel? get latestRequest => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyStatisticsProvider extends ChangeNotifier
    implements StatisticsProvider {
  int setStoreIdCallCount = 0;
  @override
  void setStoreId(String? storeId) {
    setStoreIdCallCount++;
  }

  @override
  Future<void> fetchDashboardStats({bool forceRefresh = false}) async {}
  @override
  bool get isLoading => false;
  @override
  StatsSummaryModel? get dashboardSummary => null;
  @override
  DailyStatsModel? get todayStats => null;
  @override
  String? get errorMessage => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyWalletProvider extends ChangeNotifier implements WalletProvider {
  @override
  void setStoreId(String? storeId) {}
  @override
  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {}
  @override
  bool get isLoading => false;
  @override
  List<WalletModel> get wallets => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyTransactionProvider extends ChangeNotifier
    implements TransactionProvider {
  @override
  void updateAuthState(AuthProvider auth) {}
  @override
  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {}
  @override
  bool get isLoading => false;
  @override
  List<TransactionModel> get transactions => [];
  @override
  List<TransactionModel> get todayTransactions => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyDebtProvider extends ChangeNotifier implements DebtProvider {
  @override
  void setStoreId(String? storeId) {}
  @override
  Future<void> fetchInitialDebts({bool forceRefresh = false}) async {}
  @override
  bool get isLoading => false;
  @override
  Map<String, dynamic> get summary => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('MainDashboardScreen caches initializations on rebuilds',
      (WidgetTester tester) async {
    final subProvider = DummySubscriptionProvider();
    final statProvider = DummyStatisticsProvider();

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
              create: (_) => DummyAuthProvider()),
          ChangeNotifierProvider<SubscriptionProvider>.value(
              value: subProvider),
          ChangeNotifierProvider<StatisticsProvider>.value(value: statProvider),
          ChangeNotifierProvider<WalletProvider>(
              create: (_) => DummyWalletProvider()),
          ChangeNotifierProvider<TransactionProvider>(
              create: (_) => DummyTransactionProvider()),
          ChangeNotifierProvider<DebtProvider>(
              create: (_) => DummyDebtProvider()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MainDashboardScreen()),
        ),
      );
    }

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Check initial setup calls
    final initialCallCount = statProvider.setStoreIdCallCount;
    expect(initialCallCount, greaterThan(0),
        reason: 'Initialization should happen');

    // Force a rebuild by pumping again
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Verify it wasn't called again due to didChangeDependencies
    expect(statProvider.setStoreIdCallCount, initialCallCount,
        reason: 'Should not re-initialize on rebuild');
  });
}
