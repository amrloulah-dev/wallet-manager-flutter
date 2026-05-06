import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/wallet_provider.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../providers/debt_provider.dart';
import '../../../../providers/statistics_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/common/double_back_to_exit_wrapper.dart';
import 'package:walletmanager/presentation/widgets/dashboard/app_drawer.dart';
import '../dashboard/widgets/subscription_banner.dart';
import '../../../../providers/subscription_provider.dart';
import '../subscription/payment_success_modal.dart';

import 'widgets/dashboard_welcome_header.dart';
import 'widgets/dashboard_quick_stats.dart';
import 'widgets/dashboard_quick_actions.dart';
import 'widgets/dashboard_alerts.dart';
import 'widgets/dashboard_recent_txns.dart';
import '../../../../core/enums/subscription_enums.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  late VoidCallback _subListener;
  late SubscriptionProvider _subscriptionProvider;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _subscriptionProvider = context.read<SubscriptionProvider>();
    _subListener = () {
      if (mounted) {
        _maybeShowSuccessModal(_subscriptionProvider);
      }
    };
    Future.microtask(() {
      _initializeProviders();
      _fetchInitialData();
      // H010: Listen for payment success modal trigger
      _checkPaymentSuccessModal();
    });
  }

  @override
  void dispose() {
    _subscriptionProvider.removeListener(_subListener);
    super.dispose();
  }

  /// H010: Check if SubscriptionProvider signals an unseen payment success.
  /// Shows the PaymentSuccessModal and marks it as seen so it won't fire again.
  void _checkPaymentSuccessModal() {
    if (!mounted) return;
    // Initial check
    _maybeShowSuccessModal(_subscriptionProvider);
    // Ongoing listener for real-time transitions
    _subscriptionProvider.addListener(_subListener);
  }

  void _maybeShowSuccessModal(SubscriptionProvider subProvider) {
    if (!mounted) return;
    if (!subProvider.hasSeenSuccessModal) {
      // Verify the user actually upgraded (not just a flag reset)
      final planId = context.read<AuthProvider>().currentStore?.subscription.planId;
      if (planId == SubscriptionPlan.proYearly || planId == SubscriptionPlan.lifetime) { // ENUM refactor
        subProvider.markSuccessModalSeen();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            PaymentSuccessModal.show(context);
          }
        });
      }
    }
  }

  void _initializeProviders() {
    if (_isInitialized || !mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentStoreId != null) {
      context
          .read<StatisticsProvider>()
          .setStoreId(authProvider.currentStoreId);
      context.read<WalletProvider>().setStoreId(authProvider.currentStoreId!);
      context.read<TransactionProvider>().updateAuthState(authProvider);
      context.read<DebtProvider>().setStoreId(authProvider.currentStoreId!);
      _isInitialized = true;
    }
  }

  void _fetchInitialData() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentStoreId != null) {
      context.read<StatisticsProvider>().fetchDashboardStats();
      context.read<WalletProvider>().fetchInitialWallets();
      context.read<TransactionProvider>().fetchInitialTransactions();
      context.read<DebtProvider>().fetchInitialDebts();
    }
  }

  Future<void> _refreshData() async {
    final statsProvider = context.read<StatisticsProvider>();
    await Future.wait([
      statsProvider.fetchDashboardStats(forceRefresh: true),
      context.read<WalletProvider>().refresh(),
      context
          .read<TransactionProvider>()
          .fetchInitialTransactions(forceRefresh: true),
      context.read<DebtProvider>().fetchInitialDebts(forceRefresh: true),
    ]);
  }

  void _navigateToCreateTransaction() {
    Navigator.pushNamed(context, RouteConstants.createTransaction);
  }

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExitWrapper(
      child: Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.home),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, RouteConstants.settings),
              ),
            ],
          ),
          drawer: const AppDrawer(),
          body: RefreshIndicator(
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const DashboardWelcomeHeader(),
                  const SubscriptionBanner(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        DashboardQuickStats(),
                        SizedBox(height: 24),
                        DashboardQuickActions(),
                        SizedBox(height: 24),
                        DashboardAlerts(),
                        DashboardRecentTxns(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _navigateToCreateTransaction,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.newTransaction),
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primary,
          )),
    );
  }
}
