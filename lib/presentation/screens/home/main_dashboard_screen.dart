import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/stats_summary_model.dart';
import '../../../data/models/daily_stats_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../data/models/wallet_model.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/statistics_provider.dart';
import '../../widgets/common/skeleton_list.dart';
import '../../widgets/dashboard/stats_card.dart';
import '../../widgets/dashboard/quick_action_card.dart';
import '../../widgets/dashboard/section_header.dart';
import '../../widgets/dashboard/alert_card.dart';
import '../../widgets/transaction/transaction_card.dart';
import 'package:walletmanager/presentation/widgets/common/skeleton_card.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/common/double_back_to_exit_wrapper.dart';
import 'package:walletmanager/presentation/widgets/dashboard/app_drawer.dart';
import '../dashboard/widgets/subscription_banner.dart';

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _fetchInitialData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentStoreId != null) {
      context
          .read<StatisticsProvider>()
          .setStoreId(authProvider.currentStoreId);
      context.read<WalletProvider>().setStoreId(authProvider.currentStoreId!);
      context.read<TransactionProvider>().updateAuthState(authProvider);
      context.read<DebtProvider>().setStoreId(authProvider.currentStoreId!);
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
      context.read<WalletProvider>().fetchInitialWallets(forceRefresh: true),
      context
          .read<TransactionProvider>()
          .fetchInitialTransactions(forceRefresh: true),
      context.read<DebtProvider>().fetchInitialDebts(forceRefresh: true),
    ]);
  }

  void _navigateToCreateTransaction() {
    Navigator.pushNamed(context, RouteConstants.createTransaction);
  }

  String _getGreetingMessage(BuildContext context) {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppLocalizations.of(context)!.goodMorning;
    }
    if (hour < 17) {
      return AppLocalizations.of(context)!.goodAfternoon;
    }
    return AppLocalizations.of(context)!.goodEvening;
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
                  _buildWelcomeHeader(),
                  const SubscriptionBanner(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickStats(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 24),
                        _buildAlerts(),
                        _buildRecentTransactions(),
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

  Widget _buildWelcomeHeader() {
    return Selector<AuthProvider, String?>(
      selector: (context, provider) => provider.currentUser?.fullName,
      builder: (context, fullName, child) {
        final avatarLetter = fullName?.isNotEmpty == true
            ? fullName![0].toUpperCase()
            : 'U';
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border(
                bottom: BorderSide(color: AppColors.border(context), width: 1)),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text(
                avatarLetter,
                style: AppTextStyles.h3.copyWith(color: Colors.white),
              ),
            ),
            title: Text(
              _getGreetingMessage(context),
              style: AppTextStyles.labelSmall
                  .copyWith(color: AppColors.textSecondary(context)),
            ),
            subtitle: Text(
              fullName ?? AppLocalizations.of(context)!.user,
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.textPrimary(context)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Selector<StatisticsProvider,
        ({StatsSummaryModel? summary, DailyStatsModel? today, bool isLoading, String? error})>(
      selector: (context, provider) => (
        summary: provider.dashboardSummary,
        today: provider.todayStats,
        isLoading: provider.isLoading,
        error: provider.errorMessage,
      ),
      builder: (context, data, child) {
        try {
          if (data.isLoading && data.summary == null) {
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children:
                  List.generate(4, (index) => const SkeletonCard(height: 80)),
            );
          }
          if (data.error != null && data.summary == null) {
            return Center(child: Text(data.error!));
          }

          final stats = data.summary;
          if (stats == null) {
            return Center(
                child: Text(AppLocalizations.of(context)!.errorLoadingStats));
          }

          final lastUpdated = stats.lastUpdated.toDate();
          final formattedTime = DateFormat.yMMMd().add_jm().format(lastUpdated);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final isSmallScreen = width < 360;
                  final isMediumScreen = width >= 360 && width < 600;

                  int crossAxisCount;
                  double childAspectRatio;

                  if (isSmallScreen) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.6;
                  } else if (isMediumScreen) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.8;
                  } else {
                    crossAxisCount = 4;
                    childAspectRatio = 1.5;
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: childAspectRatio,
                    children: [
                      StatsCard(
                          title: AppLocalizations.of(context)!.totalWallets,
                          value: stats.totalWallets.toString(),
                          icon: Icons.account_balance_wallet_outlined,
                          color: Colors.blue.shade700,
                          onTap: () {
                            final user = context.read<AuthProvider>().currentUser;
                            final canAccess = user?.role == 'owner' ||
                                (user?.permissions?.viewWallets ?? false);

                            if (canAccess) {
                              Navigator.pushNamed(
                                  context, RouteConstants.walletsList);
                            } else {
                              ToastUtils.showError(
                                  AppLocalizations.of(context)!.accessDenied);
                            }
                          }),
                      StatsCard(
                        title:
                            '${AppLocalizations.of(context)!.totalTransactions} ',
                        value: (data.today?.transactionCount ?? 0)
                            .toString(),
                        icon: Icons.swap_horiz,
                        color: Colors.green.shade700,
                        onTap: () {
                          final user = context.read<AuthProvider>().currentUser;
                          if (user != null &&
                              (user.role == 'owner' ||
                                  user.hasPermission(
                                      (p) => p.createTransaction) ||
                                  user.hasPermission(
                                      (p) => p.viewAllTransactions))) {
                            Navigator.pushNamed(
                                context, RouteConstants.todayTransactions);
                          } else {
                            ToastUtils.showError(
                                AppLocalizations.of(context)!.accessDenied);
                          }
                        },
                      ),
                      StatsCard(
                        title:
                            '${AppLocalizations.of(context)!.totalCommission} ',
                        value: (data.today?.totalCommission ?? 0)
                            .toInt()
                            .toString(),
                        icon: Icons.attach_money,
                        color: Colors.orange.shade800,
                        onTap: () {
                          final user = context.read<AuthProvider>().currentUser;
                          if (user != null &&
                              (user.role == 'owner' ||
                                  user.hasPermission(
                                      (p) => p.createTransaction) ||
                                  user.hasPermission(
                                      (p) => p.viewAllTransactions))) {
                            Navigator.pushNamed(
                                context, RouteConstants.todayTransactions);
                          } else {
                            ToastUtils.showError(
                                AppLocalizations.of(context)!.accessDenied);
                          }
                        },
                      ),
                      StatsCard(
                        title: AppLocalizations.of(context)!.openDebts,
                        value: stats.openDebtsCount.toString(),
                        icon: Icons.credit_card_off_outlined,
                        color: Colors.red.shade700,
                        onTap: () {
                          final user = context.read<AuthProvider>().currentUser;
                          final canAccess = user?.role == 'owner' ||
                              (user?.permissions?.viewDebts ?? false);

                          if (canAccess) {
                            Navigator.pushNamed(
                                context, RouteConstants.debtsList);
                          } else {
                            ToastUtils.showError(
                                AppLocalizations.of(context)!.accessDenied);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),

              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${AppLocalizations.of(context)!.lastUpdated} $formattedTime',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
              ),
            ],
          );
        } catch (e) {
          return Center(
            child: Text(
              "UI Error: $e",
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
      },
    );
  }

  Widget _buildQuickActions() {
    return Selector<StatisticsProvider, int>(
      selector: (context, provider) => provider.dashboardSummary?.openDebtsCount ?? 0,
      builder: (context, openDebtsCount, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isSmallScreen = width < 360;
            final isMediumScreen = width >= 360 && width < 600;

            int crossAxisCount;
            double childAspectRatio;
            double horizontalPadding;

            if (isSmallScreen) {
              crossAxisCount = 3;
              childAspectRatio = 0.8;
              horizontalPadding = 12;
            } else if (isMediumScreen) {
              crossAxisCount = 3;
              childAspectRatio = .95;
              horizontalPadding = 16;
            } else {
              crossAxisCount = 6;
              childAspectRatio = 1.0;
              horizontalPadding = 16;
            }

            final List<Widget> actions = [
              QuickActionCard(
                title: AppLocalizations.of(context)!.newTransaction,
                icon: Icons.add_circle_outline,
                color: AppColors.primary,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null &&
                      user.hasPermission((p) => p.createTransaction)) {
                    _navigateToCreateTransaction();
                  } else {
                    ToastUtils.showError('ليس لديك صلاحية لإنشاء معاملة');
                  }
                },
              ),
              QuickActionCard(
                title: AppLocalizations.of(context)!.newWallet,
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.orange.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null && user.hasPermission((p) => p.createWallet)) {
                    Navigator.pushNamed(context, RouteConstants.walletForm);
                  } else {
                    ToastUtils.showError('ليس لديك صلاحية لإنشاء محفظة');
                  }
                },
              ),
              QuickActionCard(
                title: '${AppLocalizations.of(context)!.newDebt} ($openDebtsCount)',
                icon: Icons.post_add_outlined,
                color: AppColors.error,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null && user.hasPermission((p) => p.createDebt)) {
                    Navigator.pushNamed(context, RouteConstants.addDebt);
                  } else {
                    ToastUtils.showError('ليس لديك صلاحية لإنشاء دين');
                  }
                },
              ),
              QuickActionCard(
                title: AppLocalizations.of(context)!.viewWallets,
                icon: Icons.wallet,
                color: Colors.blue.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == 'owner' ||
                      (user?.permissions?.viewWallets ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(context, RouteConstants.walletsList);
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
              ),
              QuickActionCard(
                title: AppLocalizations.of(context)!.statistics,
                icon: Icons.bar_chart,
                color: Colors.purple.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null &&
                      user.hasPermission((p) => p.viewDashboardStats)) {
                    Navigator.pushNamed(context, RouteConstants.generalStatistics);
                  } else {
                    ToastUtils.showError('ليس لديك صلاحية لعرض الإحصائيات');
                  }
                },
              ),
              QuickActionCard(
                title: AppLocalizations.of(context)!.viewDebts,
                icon: Icons.credit_card,
                color: Colors.red.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == 'owner' ||
                      (user?.permissions?.viewDebts ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(context, RouteConstants.debtsList);
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
              ),
              QuickActionCard(
                title: AppLocalizations.of(context)!.manageEmployees,
                icon: Icons.people_alt_outlined,
                color: Colors.teal.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null && user.role == 'owner') {
                    Navigator.pushNamed(context, RouteConstants.manageEmployees);
                  } else {
                    ToastUtils.showError('هذه الخاصية للمالك فقط');
                  }
                },
              ),
            ];

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  SectionHeader(title: AppLocalizations.of(context)!.quickActions),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: childAspectRatio,
                    children: actions,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAlerts() {
    // Outer Selector: WalletProvider — only rebuilds when the list of
    // wallets at ≥90% daily limit changes (by walletId identity).
    return Selector<WalletProvider,
        ({bool isLoading, List<WalletModel> alertWallets})>(
      selector: (context, wp) => (
        isLoading: wp.isLoading,
        alertWallets: wp.wallets
            .where((w) => w.getLimits().dailyPercentage >= 90)
            .toList(),
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          !listEquals(
            prev.alertWallets.map((w) => w.walletId).toList(),
            next.alertWallets.map((w) => w.walletId).toList(),
          ),
      builder: (context, walletData, child) {
        if (walletData.isLoading) {
          return const SkeletonCard(height: 80);
        }

        // Inner Selector: DebtProvider — only rebuilds when openDebtsCount changes.
        return Selector<DebtProvider, int>(
          selector: (context, dp) => dp.summary['openDebtsCount'] ?? 0,
          builder: (context, openDebtsCount, child) {
            final List<Widget> alerts = [];

            for (var wallet in walletData.alertWallets) {
              alerts.add(AlertCard(
                message: AppLocalizations.of(context)!
                    .walletAlertMessage(wallet.phoneNumber),
                type: AlertType.warning,
                onActionTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == 'owner' ||
                      (user?.permissions?.viewWallets ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(
                      context,
                      RouteConstants.walletDetails,
                      arguments: wallet.walletId,
                    );
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
                actionText: AppLocalizations.of(context)!.viewDetails,
              ));
            }

            if (openDebtsCount > 0) {
              alerts.add(AlertCard(
                message:
                    AppLocalizations.of(context)!.openDebtsAlert(openDebtsCount),
                type: AlertType.error,
                onActionTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == 'owner' ||
                      (user?.permissions?.viewDebts ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(context, RouteConstants.debtsList);
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
                actionText: AppLocalizations.of(context)!.viewDebts,
              ));
            }

            if (alerts.isEmpty) {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 24),
                  SectionHeader(title: AppLocalizations.of(context)!.alerts),
                  const SizedBox(height: 12),
                  ...alerts.map((alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: alert,
                      )),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    // Selector: Only rebuilds when the top-5 transaction list or loading state changes.
    return Selector<TransactionProvider,
        ({bool isLoading, List<TransactionModel> recentFive})>(
      selector: (context, provider) => (
        isLoading: provider.isLoading,
        recentFive: provider.transactions.take(5).toList(),
      ),
      shouldRebuild: (prev, next) =>
          prev.isLoading != next.isLoading ||
          !listEquals(
            prev.recentFive.map((t) => t.transactionId).toList(),
            next.recentFive.map((t) => t.transactionId).toList(),
          ),
      builder: (context, data, child) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              SectionHeader(
                title: AppLocalizations.of(context)!.recentTransactions,
                actionText: AppLocalizations.of(context)!.viewAll,
                onActionTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null &&
                      (user.role == 'owner' ||
                          user.hasPermission((p) => p.createTransaction) ||
                          user.hasPermission((p) => p.viewAllTransactions))) {
                    Navigator.pushNamed(
                        context, RouteConstants.todayTransactions);
                  } else {
                    ToastUtils.showError(
                        AppLocalizations.of(context)!.accessDenied);
                  }
                },
              ),
              const SizedBox(height: 12),
              if (data.isLoading)
                const SkeletonList(itemCount: 2, itemHeight: 80)
              else if (data.recentFive.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    AppLocalizations.of(context)!.noTransactionsToday,
                    style: AppTextStyles.bodyMedium,
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.recentFive.length,
                  itemBuilder: (context, index) {
                    final transaction = data.recentFive[index];
                    return TransactionCard(
                      key: ValueKey('recent_tx_${transaction.transactionId}'),
                      transaction: transaction,
                      onTap: () {
                        final user = context.read<AuthProvider>().currentUser;
                        if (user != null &&
                            user.hasPermission((p) => p.viewAllTransactions)) {
                          Navigator.pushNamed(
                            context,
                            RouteConstants.transactionDetails,
                            arguments: transaction.transactionId,
                          );
                        } else {
                          ToastUtils.showError(
                              'ليس لديك صلاحية لعرض تفاصيل المعاملة');
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
