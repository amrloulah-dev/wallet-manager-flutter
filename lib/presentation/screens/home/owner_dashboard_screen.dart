import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Removed
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';
// import 'package:walletmanager/core/utils/toast_utils.dart'; // Removed

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

  Future<void> _showLogoutDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool? confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.logout,
      message: AppLocalizations.of(context)!.logoutConfirmation,
      confirmText: AppLocalizations.of(context)!.exit,
      type: DialogType.danger,
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          RouteConstants.loginLanding,
          (route) => false,
        );
      }
    }
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

  // DateTime? currentBackPressTime; // Removed

  // 1️⃣ انسخ دالة النقل هنا (داخل الكلاس)
  Future<void> migrateUserAccountSurgical() async {
    // ⚠️⚠️⚠️ هام جداً: استبدل القيم دي بالقيم الحقيقية
    final String oldUid = "B1yitBr7U9bTQD1sruJjS8ftxD62";
    final String newUid = "6M3p202It9YnnBO3RI31zya8NZ52";

    // إظهار تنبيه إن العملية بدأت
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🚀 بدأت عملية النقل... انتظر قليلاً')),
    );

    final firestore = FirebaseFirestore.instance;
    int batchCount = 0;
    WriteBatch batch = firestore.batch();

    Future<void> commitBatchIfNeeded() async {
      if (batchCount >= 450) {
        await batch.commit();
        batch = firestore.batch();
        batchCount = 0;
      }
    }

    try {
      // --- نفس كود النقل اللي اتفقنا عليه V4 ---

      // 1. تنظيف المفتاح المؤقت
      QuerySnapshot tempKeyQuery = await firestore
          .collection('license_keys')
          .where('usedBy', isEqualTo: newUid)
          .get();

      if (tempKeyQuery.docs.isEmpty) {
        tempKeyQuery = await firestore
            .collection('license_keys')
            .where('ownerId', isEqualTo: newUid)
            .get();
      }

      for (var doc in tempKeyQuery.docs) {
        batch.update(
            doc.reference, {'usedBy': null, 'ownerId': null, 'isUsed': false});
        batchCount++;
      }

      // 2. نقل البروفايل
      DocumentSnapshot oldStoreDoc =
          await firestore.collection('stores').doc(oldUid).get();
      if (oldStoreDoc.exists) {
        batch.set(
            firestore.collection('stores').doc(newUid), oldStoreDoc.data()!);
        batchCount++;
      }

      // 3. نقل الإحصائيات (Summary)
      DocumentSnapshot oldStatsDoc = await firestore
          .collection('stores')
          .doc(oldUid)
          .collection('stats')
          .doc('summary')
          .get();
      if (oldStatsDoc.exists) {
        batch.set(
            firestore
                .collection('stores')
                .doc(newUid)
                .collection('stats')
                .doc('summary'),
            oldStatsDoc.data()!);
        batchCount++;
      }

      // 4. نقل الإحصائيات اليومية
      QuerySnapshot dailyStatsQuery = await firestore
          .collection('stores')
          .doc(oldUid)
          .collection('daily_stats')
          .get();
      for (var doc in dailyStatsQuery.docs) {
        await commitBatchIfNeeded();
        batch.set(
            firestore
                .collection('stores')
                .doc(newUid)
                .collection('daily_stats')
                .doc(doc.id),
            doc.data() as Map<String, dynamic>);
        batchCount++;
      }

      // 5. نقل Root Collections
      final collectionsToUpdate = ['wallets', 'debts', 'transactions', 'users'];
      for (String collection in collectionsToUpdate) {
        QuerySnapshot query = await firestore
            .collection(collection)
            .where('storeId', isEqualTo: oldUid)
            .get();
        for (var doc in query.docs) {
          await commitBatchIfNeeded();
          batch.update(doc.reference, {'storeId': newUid});
          batchCount++;
        }
      }

      // 6. نقل المفتاح الأصلي
      QuerySnapshot realLicenseQuery = await firestore
          .collection('license_keys')
          .where('usedBy', isEqualTo: oldUid)
          .get();
      if (realLicenseQuery.docs.isEmpty) {
        realLicenseQuery = await firestore
            .collection('license_keys')
            .where('ownerId', isEqualTo: oldUid)
            .get();
      }
      for (var doc in realLicenseQuery.docs) {
        await commitBatchIfNeeded();
        batch.update(doc.reference, {'usedBy': newUid, 'ownerId': newUid});
        batchCount++;
      }

      // التنفيذ
      if (batchCount > 0) await batch.commit();

      // رسالة نجاح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 تم النقل بنجاح! اخرج وادخل تاني.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // رسالة خطأ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🚨 خطأ: $e'), backgroundColor: Colors.red),
      );
    }
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

  Widget _buildDrawer() {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final store = authProvider.currentStore;
    final avatarLetter = user?.fullName.isNotEmpty == true
        ? user!.fullName[0].toUpperCase()
        : 'U';

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
                    backgroundColor:
                        AppColors.primary.withAlpha((0.1 * 255).round()),
                    child: Text(
                      avatarLetter,
                      style:
                          AppTextStyles.h1.copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? AppLocalizations.of(context)!.user,
                    style: AppTextStyles.h3
                        .copyWith(color: AppColors.textPrimary(context)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    store?.storeName ?? AppLocalizations.of(context)!.storeName,
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
                    title: AppLocalizations.of(context)!.home,
                    icon: Icons.dashboard_outlined,
                    isSelected: true, // Current screen
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.wallets,
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      if (context.read<AuthProvider>().isOwner) {
                        Navigator.pushNamed(
                            context, RouteConstants.walletsList);
                      }
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.transactions,
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, RouteConstants.todayTransactions);
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.debts,
                    icon: Icons.credit_card_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteConstants.debtsList);
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.statistics,
                    icon: Icons.bar_chart_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(
                          context, RouteConstants.generalStatistics);
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.manageEmployees,
                    icon: Icons.people_alt_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      if (authProvider.isOwner) {
                        Navigator.pushNamed(
                            context, RouteConstants.manageEmployees);
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
                    title: AppLocalizations.of(context)!.settings,
                    icon: Icons.settings_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, RouteConstants.settings);
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.logout,
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
              colors: [
                AppColors.primary,
                AppColors.primary.withAlpha((0.8 * 255).round())
              ],
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
                  _getGreetingMessage(context),
                  style: AppTextStyles.h3.copyWith(color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  authProvider.currentUser?.fullName ??
                      AppLocalizations.of(context)!.user,
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
                          Navigator.pushNamed(
                              context, RouteConstants.walletsList);
                        }),
                    StatsCard(
                      title:
                          '${AppLocalizations.of(context)!.totalTransactions} (Day)',
                      value: (provider.todayStats?.transactionCount ?? 0)
                          .toString(),
                      icon: Icons.swap_horiz,
                      color: Colors.green.shade700,
                      onTap: () => Navigator.pushNamed(
                          context, RouteConstants.todayTransactions),
                    ),
                    StatsCard(
                      title:
                          '${AppLocalizations.of(context)!.totalCommission} (Day)',
                      value: (provider.todayStats?.totalCommission ?? 0)
                          .toInt()
                          .toString(),
                      icon: Icons.attach_money,
                      color: Colors.orange.shade800,
                      onTap: () => Navigator.pushNamed(
                          context, RouteConstants.todayTransactions),
                    ),
                    StatsCard(
                      title: AppLocalizations.of(context)!.openDebts,
                      value: stats.openDebtsCount.toString(),
                      icon: Icons.credit_card_off_outlined,
                      color: Colors.red.shade700,
                      onTap: () => Navigator.pushNamed(
                          context, RouteConstants.debtsList),
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
            onTap: _navigateToCreateTransaction,
          ),
          QuickActionCard(
            title: AppLocalizations.of(context)!.newWallet,
            icon: Icons.account_balance_wallet_outlined,
            color: Colors.orange.shade700,
            onTap: () {
              Navigator.pushNamed(context, RouteConstants.walletForm);
            },
          ),
          Consumer<StatisticsProvider>(
            builder: (context, provider, _) {
              final openDebts = provider.dashboardSummary?.openDebtsCount ?? 0;
              return QuickActionCard(
                title: '${AppLocalizations.of(context)!.newDebt} ($openDebts)',
                icon: Icons.post_add_outlined,
                color: AppColors.error,
                onTap: () =>
                    Navigator.pushNamed(context, RouteConstants.addDebt),
              );
            },
          ),
          QuickActionCard(
            title: AppLocalizations.of(context)!.viewWallets,
            icon: Icons.wallet,
            color: Colors.blue.shade700,
            onTap: () {
              Navigator.pushNamed(context, RouteConstants.walletsList);
            },
          ),
          QuickActionCard(
            title: AppLocalizations.of(context)!.statistics,
            icon: Icons.bar_chart,
            color: Colors.purple.shade700,
            onTap: () {
              Navigator.pushNamed(context, RouteConstants.generalStatistics);
            },
          ),
          QuickActionCard(
            title: AppLocalizations.of(context)!.viewDebts,
            icon: Icons.credit_card,
            color: Colors.red.shade700,
            onTap: () => Navigator.pushNamed(context, RouteConstants.debtsList),
          ),
          QuickActionCard(
            title: AppLocalizations.of(context)!.manageEmployees,
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
                if (context.read<AuthProvider>().isOwner) {
                  Navigator.pushNamed(
                    context,
                    RouteConstants.walletDetails,
                    arguments: wallet.walletId,
                  );
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
            onActionTap: () =>
                Navigator.pushNamed(context, RouteConstants.debtsList),
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
                onActionTap: () => Navigator.pushNamed(
                    context, RouteConstants.todayTransactions),
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
