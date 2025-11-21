import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';

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

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.read<AuthProvider>();
    if (authProvider.currentStoreId != null) {
      context.read<StatisticsProvider>().setStoreId(authProvider.currentStoreId);
      context.read<WalletProvider>().setStoreId(authProvider.currentStoreId!);
      context.read<TransactionProvider>().setStoreId(authProvider.currentStoreId!);
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
      context.read<TransactionProvider>().fetchInitialTransactions(forceRefresh: true),
      context.read<DebtProvider>().fetchInitialDebts(forceRefresh: true),
    ]);
  }

  void _navigateToCreateTransaction() {
    Navigator.pushNamed(context, RouteConstants.createTransaction);
  }

  Future<void> _showLogoutDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool? confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد أنك تريد تسجيل الخروج؟',
      confirmText: 'خروج',
      type: DialogType.danger,
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, RouteConstants.storeRegistration);
      }
    }
  }

  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'صباح الخير 🌅';
    }
    if (hour < 17) {
      return 'مساء الخير ☀️';
    }
    return 'مساء الخير 🌙';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, RouteConstants.settings),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeHeader(),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTransaction,
        icon: const Icon(Icons.add),
        label: const Text('معاملة جديدة'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDrawer() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final store = authProvider.currentStore;
    final avatarLetter =
        user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U';

    return Drawer(
      elevation: 2,
      backgroundColor: AppColors.surface(context),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary.withAlpha((0.1 * 255).round()),
                    child: Text(
                      avatarLetter,
                      style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? 'مستخدم',
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.textPrimary(context)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store?.storeName ?? 'متجر',
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondary(context)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(8.0),
                children: [
                  _DrawerMenuTile(
                    title: 'الرئيسية',
                    icon: Icons.dashboard_outlined,
                    isSelected: true, // Current screen
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerMenuTile(
                    title: 'المحافظ',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      if (context.read<AuthProvider>().isOwner) {
                        Navigator.pushNamed(context, RouteConstants.walletsList);
                      }
                    },
                  ),
                  _DrawerMenuTile(
                    title: 'المعاملات',
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, RouteConstants.todayTransactions);
                    },
                  ),
                  _DrawerMenuTile(
                    title: 'الديون',
                    icon: Icons.credit_card_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteConstants.debtsList);
                    },
                  ),
                  _DrawerMenuTile(
                    title: 'الإحصائيات',
                    icon: Icons.bar_chart_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, RouteConstants.generalStatistics);
                    },
                  ),
                  _DrawerMenuTile(
                    title: 'إدارة الموظفين',
                    icon: Icons.people_alt_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      if (authProvider.isOwner) {
                        Navigator.pushNamed(context, RouteConstants.manageEmployees);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Footer Items
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _DrawerMenuTile(
                    title: 'الإعدادات',
                    icon: Icons.settings_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteConstants.settings);
                    },
                  ),
                  _DrawerMenuTile(
                    title: 'تسجيل الخروج',
                    icon: Icons.logout,
                    iconColor: AppColors.error,
                    textColor: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _showLogoutDialog();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withAlpha((0.8 * 255).round())],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getGreetingMessage(),
                  style: AppTextStyles.h3.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.currentUser?.fullName ?? 'مستخدم',
                  style: AppTextStyles.h1.copyWith(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
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
            children: List.generate(4, (index) => const SkeletonCard(height: 80)),
          );
        }
        if (provider.errorMessage != null && provider.dashboardSummary == null) {
          return Center(child: Text(provider.errorMessage!));
        }

        final stats = provider.dashboardSummary;
        if (stats == null) {
          return const Center(child: Text('لا يمكن تحميل الإحصائيات'));
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
                      title: 'إجمالي المحافظ',
                      value: stats.totalWallets.toString(),
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.blue.shade700,
                      onTap: () {
                        if (context.read<AuthProvider>().isOwner) {
                          Navigator.pushNamed(context, RouteConstants.walletsList);
                        }
                      }
                    ),
                    StatsCard(
                      title: 'إجمالي المعاملات',
                      value: stats.totalTransactions.toString(),
                      icon: Icons.swap_horiz,
                      color: Colors.green.shade700,
                      onTap: () => Navigator.pushNamed(context, RouteConstants.todayTransactions),
                    ),
                    StatsCard(
                      title: 'إجمالي العمولات',
                      value: stats.totalCommission.toInt().toString(),
                      icon: Icons.attach_money,
                      color: Colors.orange.shade800,
                      onTap: () => Navigator.pushNamed(context, RouteConstants.todayTransactions),
                    ),
                    StatsCard(
                      title: 'ديون مفتوحة',
                      value: stats.openDebtsCount.toString(),
                      icon: Icons.credit_card_off_outlined,
                      color: Colors.red.shade700,
                      onTap: () => Navigator.pushNamed(context, RouteConstants.debtsList),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'آخر تحديث: $formattedTime',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(context)),
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
            title: 'معاملة جديدة',
            icon: Icons.add_circle_outline,
            color: AppColors.primary,
            onTap: _navigateToCreateTransaction,
          ),
          QuickActionCard(
            title: 'محفظة جديدة',
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.orange.shade700,
            onTap: (){
              if(context.read<AuthProvider>().isOwner){
                Navigator.pushNamed(context, RouteConstants.walletForm);
              }
            },
          ),
          Consumer<StatisticsProvider>(
            builder: (context, provider, _) {
              final openDebts = provider.dashboardSummary?.openDebtsCount ?? 0;
              return QuickActionCard(
                title: 'دين جديد ($openDebts)',
                icon: Icons.post_add_outlined,
                color: AppColors.error,
                onTap: () => Navigator.pushNamed(context, RouteConstants.addDebt),
              );
            },
          ),
          QuickActionCard(
            title: 'عرض المحافظ',
            icon: Icons.wallet,
            color: Colors.blue.shade700,
            onTap: (){
              if(context.read<AuthProvider>().isOwner){
                Navigator.pushNamed(context, RouteConstants.walletsList);
              }
            },
          ),
          QuickActionCard(
            title: 'الإحصائيات',
            icon: Icons.bar_chart,
            color: Colors.purple.shade700,
            onTap: (){
              if(context.read<AuthProvider>().isOwner){
                Navigator.pushNamed(context, RouteConstants.generalStatistics);
              }
            },
          ),
          QuickActionCard(
            title: 'عرض الديون',
            icon: Icons.credit_card,
            color: Colors.red.shade700,
            onTap: ()=> Navigator.pushNamed(context, RouteConstants.debtsList),
          ),
          QuickActionCard(
            title: 'إدارة الموظفين',
            icon: Icons.people_alt_outlined,
            color: Colors.teal.shade700,
            onTap: () {
              if (context.read<AuthProvider>().isOwner) {
                Navigator.pushNamed(context, RouteConstants.manageEmployees);
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
              const SectionHeader(title: 'إجراءات سريعة'),
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
          if (wallet.sendLimits.dailyPercentage >= 90) {
            alerts.add(AlertCard(
              message: 'محفظة ${wallet.phoneNumber} على وشك الوصول للحد اليومي للإرسال.',
              type: AlertType.warning,
              onActionTap: () {
                if(context.read<AuthProvider>().isOwner){
                  Navigator.pushNamed(
                    context,
                    RouteConstants.walletDetails,
                    arguments: wallet.walletId,
                  );
                }
              },
              actionText: 'عرض التفاصيل',
            ));
          }
        }

        final openDebtsCount = debtProvider.summary['openDebtsCount'] ?? 0;
        if (openDebtsCount > 0) {
          alerts.add(AlertCard(
            message: 'لديك $openDebtsCount ديون مفتوحة.',
            type: AlertType.error,
            onActionTap: () => Navigator.pushNamed(context, RouteConstants.debtsList),
            actionText: 'عرض الديون',
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
              const SectionHeader(title: 'تنبيهات'),
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
                title: 'آخر المعاملات',
                actionText: 'عرض الكل',
                onActionTap: () => Navigator.pushNamed(context, RouteConstants.todayTransactions),
              ),
              const SizedBox(height: 12),
              if (provider.isLoading)
                const SkeletonList(itemCount: 2, itemHeight: 80)
              else if (provider.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'لا توجد معاملات اليوم.',
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
                      onTap: () => Navigator.pushNamed(
                        context,
                        RouteConstants.transactionDetails,
                        arguments: transaction.transactionId,
                      ),
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

class _DrawerMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;
  final Color? iconColor;
  final Color? textColor;

  const _DrawerMenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.isSelected = false,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ??
        (isSelected ? AppColors.primary : AppColors.textSecondary(context));
    final effectiveTextColor = textColor ??
        (isSelected ? AppColors.primary : AppColors.textPrimary(context));

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: effectiveIconColor),
      title: Text(
        title,
        style: AppTextStyles.labelLarge.copyWith(
          color: effectiveTextColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      selected: isSelected,
      selectedTileColor: AppColors.primary.withAlpha((0.1 * 255).round()),
      hoverColor: AppColors.primary.withAlpha((0.05 * 255).round()),
      splashColor: AppColors.primary.withAlpha((0.1 * 255).round()),
    );
  }
}