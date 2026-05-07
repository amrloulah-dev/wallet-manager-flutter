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
import 'package:walletmanager/data/models/stats_summary_model.dart';
import 'package:walletmanager/data/models/daily_stats_model.dart';
import 'package:walletmanager/data/models/subscription_request_model.dart';
import 'package:walletmanager/data/models/wallet_model.dart';
import 'package:walletmanager/data/models/transaction_model.dart';

import 'package:walletmanager/data/models/user_model.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/data/models/store_model.dart';
import 'package:walletmanager/core/enums/subscription_enums.dart';

class DummyAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  String? get currentStoreId => 'store_123';
  @override
  UserModel? get currentUser => UserModel(
        userId: 'user_123',
        storeId: 'store_123',
        role: UserRole.owner,
        fullName: 'Test User',
      );
  @override
  StoreModel? get currentStore => StoreModel(
        storeId: 'store_123',
        storeName: 'Test Store',
        storePassword: 'hashed_password',
        ownerId: 'owner_123',
        ownerName: 'Owner',
        ownerEmail: 'owner@test.com',
        subscription: StoreSubscription(
          planId: SubscriptionPlan.trial,
          status: SubscriptionStatus.active,
          trialConsumed: true,
          maxWallets: 3,
          maxEmployees: 1,
          smsEnabled: true,
        ),
        settings: StoreSettings(
          currency: 'EGP',
          timezone: 'Africa/Cairo',
        ),
        stats: StoreStats(
          totalWallets: 0,
          activeWallets: 0,
          totalTransactionsToday: 0,
          totalCommissionToday: 0.0,
          totalServiceFeeToday: 0.0,
        ),
        createdAt: DateTime.now(),
      );
  @override
  bool get isTrial => true;
  @override
  int? get trialDaysRemaining => 14;
  @override
  bool get isOwner => true;
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
  SubscriptionRequestModel? get latestRequest => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyStatisticsProvider extends ChangeNotifier
    implements StatisticsProvider {
  @override
  bool get isLoading => false;
  @override
  StatsSummaryModel? get dashboardSummary => null;
  @override
  DailyStatsModel? get todayStats => null;
  @override
  String? get errorMessage => null;
  @override
  Future<void> fetchDashboardStats({bool forceRefresh = false}) async {}
  @override
  void setStoreId(String? storeId) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyWalletProvider extends ChangeNotifier implements WalletProvider {
  @override
  bool get isLoading => false;
  @override
  List<WalletModel> get wallets => [];
  @override
  void setStoreId(String? storeId) {}
  @override
  Future<void> fetchInitialWallets({bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyTransactionProvider extends ChangeNotifier
    implements TransactionProvider {
  @override
  bool get isLoading => false;
  @override
  List<TransactionModel> get transactions => [];
  @override
  void updateAuthState(AuthProvider auth) {}
  @override
  Future<void> fetchInitialTransactions({bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyDebtProvider extends ChangeNotifier implements DebtProvider {
  @override
  Map<String, dynamic> get summary => {};
  @override
  void setStoreId(String? storeId) {}
  @override
  Future<void> fetchInitialDebts({bool forceRefresh = false}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('MainDashboardScreen uses CustomScrollView and Sliver components',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
              create: (_) => DummyAuthProvider()),
          ChangeNotifierProvider<SubscriptionProvider>(
              create: (_) => DummySubscriptionProvider()),
          ChangeNotifierProvider<StatisticsProvider>(
              create: (_) => DummyStatisticsProvider()),
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
          home: MainDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify CustomScrollView is present
    expect(find.byType(CustomScrollView), findsOneWidget);

    // Verify child widgets are present (they are now slivers or wrapped in slivers)
    expect(
        find.byType(SliverPadding).evaluate().length, greaterThanOrEqualTo(4));

    // Verify no GridView/ListView has shrinkWrap: true
    final grids = tester.widgetList<GridView>(find.byType(GridView));
    for (final grid in grids) {
      expect(grid.shrinkWrap, isFalse,
          reason: 'GridView should not use shrinkWrap: true');
    }

    final lists = tester.widgetList<ListView>(find.byType(ListView));
    for (final list in lists) {
      expect(list.shrinkWrap, isFalse,
          reason: 'ListView should not use shrinkWrap: true');
    }
  });
}
