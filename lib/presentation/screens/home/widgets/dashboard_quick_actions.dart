import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../providers/statistics_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../widgets/dashboard/quick_action_card.dart';
import '../../../widgets/dashboard/section_header.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  void _navigateToCreateTransaction(BuildContext context) {
    Navigator.pushNamed(context, RouteConstants.createTransaction);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                title: l10n.newTransaction,
                icon: Icons.add_circle_outline,
                color: AppColors.primary,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null &&
                      user.hasPermission((p) => p.createTransaction)) {
                    _navigateToCreateTransaction(context);
                  } else {
                    ToastUtils.showError(l10n.noPermissionCreateTransaction);
                  }
                },
              ),
              QuickActionCard(
                title: l10n.newWallet,
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.orange.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null && user.hasPermission((p) => p.createWallet)) {
                    Navigator.pushNamed(context, RouteConstants.walletForm);
                  } else {
                    ToastUtils.showError(l10n.noPermissionCreateWallet);
                  }
                },
              ),
              QuickActionCard(
                title: '${l10n.newDebt} ($openDebtsCount)',
                icon: Icons.post_add_outlined,
                color: AppColors.error,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null && user.hasPermission((p) => p.createDebt)) {
                    Navigator.pushNamed(context, RouteConstants.addDebt);
                  } else {
                    ToastUtils.showError(l10n.noPermissionCreateDebt);
                  }
                },
              ),
              QuickActionCard(
                title: l10n.viewWallets,
                icon: Icons.wallet,
                color: Colors.blue.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == 'owner' ||
                      (user?.permissions?.viewWallets ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(context, RouteConstants.walletsList);
                  } else {
                    ToastUtils.showError(l10n.accessDenied);
                  }
                },
              ),
              QuickActionCard(
                title: l10n.statistics,
                icon: Icons.bar_chart,
                color: Colors.purple.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null &&
                      user.hasPermission((p) => p.viewDashboardStats)) {
                    Navigator.pushNamed(context, RouteConstants.generalStatistics);
                  } else {
                    ToastUtils.showError(l10n.noPermissionViewStats);
                  }
                },
              ),
              QuickActionCard(
                title: l10n.viewDebts,
                icon: Icons.credit_card,
                color: Colors.red.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  final canAccess = user?.role == 'owner' ||
                      (user?.permissions?.viewDebts ?? false);

                  if (canAccess) {
                    Navigator.pushNamed(context, RouteConstants.debtsList);
                  } else {
                    ToastUtils.showError(l10n.accessDenied);
                  }
                },
              ),
              QuickActionCard(
                title: l10n.manageEmployees,
                icon: Icons.people_alt_outlined,
                color: Colors.teal.shade700,
                onTap: () {
                  final user = context.read<AuthProvider>().currentUser;
                  if (user != null && user.role == 'owner') {
                    Navigator.pushNamed(context, RouteConstants.manageEmployees);
                  } else {
                    ToastUtils.showError(l10n.ownerOnlyFeature);
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
                  SectionHeader(title: l10n.quickActions),
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
}
