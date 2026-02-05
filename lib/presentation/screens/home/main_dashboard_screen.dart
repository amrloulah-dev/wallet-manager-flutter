import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Removed
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({super.key});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
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
                  _buildTrialBanner(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuickStats(),
                        const SizedBox(height: 24), // Increased spacing
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
          // 2️⃣ ضيف الزرار المؤقت ده هنا
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser;
        final avatarLetter = user?.fullName.isNotEmpty == true
            ? user!.fullName[0].toUpperCase()
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
              user?.fullName ?? AppLocalizations.of(context)!.user,
              style: AppTextStyles.h3
                  .copyWith(color: AppColors.textPrimary(context)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrialBanner() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isTrial) return const SizedBox.shrink();

        final days = authProvider.trialDaysRemaining ?? 0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.access_time_filled,
                  color: Colors.amber.shade800, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'نسخة تجريبية: متبقي $days أيام',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // Navigate to Settings/Contact to Renew
                  Navigator.pushNamed(context, RouteConstants.settings);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.amber.shade900,
                  textStyle: AppTextStyles.labelMedium,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(60, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('ترقية'),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Consumer<StatisticsProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.dashboardSummary == null) {
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
        if (provider.errorMessage != null &&
            provider.dashboardSummary == null) {
          return Center(child: Text(provider.errorMessage!));
        }

        final stats = provider.dashboardSummary;
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
                          '${AppLocalizations.of(context)!.totalTransactions} (Day)',
                      value: (provider.todayStats?.transactionCount ?? 0)
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
                          '${AppLocalizations.of(context)!.totalCommission} (Day)',
                      value: (provider.todayStats?.totalCommission ?? 0)
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
            const SizedBox(height: 8),
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
      },
    );
  }

  Widget _buildQuickActions() {
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
          Consumer<StatisticsProvider>(
            builder: (context, provider, _) {
              final openDebts = provider.dashboardSummary?.openDebtsCount ?? 0;
              return QuickActionCard(
                title: '${AppLocalizations.of(context)!.newDebt} ($openDebts)',
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
              );
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
  }

  Widget _buildAlerts() {
    return Consumer2<WalletProvider, DebtProvider>(
      builder: (context, walletProvider, debtProvider, child) {
        if (walletProvider.isLoading) {
          return const SkeletonCard(height: 80);
        }

        final List<Widget> alerts = [];

        final wallets = walletProvider.wallets;
        for (var wallet in wallets) {
          if (wallet.getLimits().dailyPercentage >= 90) {
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
        }

        final openDebtsCount = debtProvider.summary['openDebtsCount'] ?? 0;
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
  }

  Widget _buildRecentTransactions() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
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
              if (provider.isLoading)
                const SkeletonList(itemCount: 2, itemHeight: 80)
              else if (provider.transactions.isEmpty)
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
                  itemCount: provider.transactions.take(5).length,
                  itemBuilder: (context, index) {
                    final transaction = provider.transactions.elementAt(index);
                    return TransactionCard(
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
