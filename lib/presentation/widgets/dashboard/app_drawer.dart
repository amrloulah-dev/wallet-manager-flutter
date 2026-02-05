import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/utils/toast_utils.dart';
import '../../../l10n/arb/app_localizations.dart';
import '../../../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _showLogoutDialog(BuildContext context) async {
    final currentContext = context;
    final authProvider = currentContext.read<AuthProvider>();

    DialogUtils.showConfirmDialog(
      currentContext,
      title: AppLocalizations.of(currentContext)!.logout,
      message: AppLocalizations.of(currentContext)!.logoutConfirmation,
      confirmText: AppLocalizations.of(currentContext)!.exit,
      type: DialogType.danger,
      onConfirm: () async {
        try {
          await authProvider.logout();
          if (!currentContext.mounted) return;
          Navigator.of(currentContext).pushNamedAndRemoveUntil(
            RouteConstants.loginLanding,
            (route) => false,
          );
        } catch (e) {
          if (currentContext.mounted) {
            ToastUtils.showError(
                '${AppLocalizations.of(currentContext)!.logoutFailed}: $e');
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      final user = context.read<AuthProvider>().currentUser;
                      if (user != null &&
                          user.hasPermission((p) => p.viewWallets)) {
                        Navigator.pushNamed(
                            context, RouteConstants.walletsList);
                      } else {
                        ToastUtils.showError('ليس لديك صلاحية لعرض المحافظ');
                      }
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.transactions,
                    icon: Icons.receipt_long_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      final user = context.read<AuthProvider>().currentUser;
                      if (user != null &&
                          user.hasPermission((p) => p.viewAllTransactions)) {
                        Navigator.pushNamed(
                            context, RouteConstants.todayTransactions);
                      } else {
                        ToastUtils.showError('ليس لديك صلاحية لعرض المعاملات');
                      }
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.debts,
                    icon: Icons.credit_card_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      final user = context.read<AuthProvider>().currentUser;
                      if (user != null &&
                          user.hasPermission((p) => p.viewDebts)) {
                        Navigator.pushNamed(context, RouteConstants.debtsList);
                      } else {
                        ToastUtils.showError('ليس لديك صلاحية لعرض الديون');
                      }
                    },
                  ),
                  _DrawerMenuTile(
                    title: AppLocalizations.of(context)!.statistics,
                    icon: Icons.bar_chart_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      final user = context.read<AuthProvider>().currentUser;
                      if (user != null &&
                          user.hasPermission((p) => p.viewDashboardStats)) {
                        Navigator.pushNamed(
                            context, RouteConstants.generalStatistics);
                      } else {
                        ToastUtils.showError('ليس لديك صلاحية لعرض الإحصائيات');
                      }
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
                      } else {
                        ToastUtils.showError('هذه الخاصية للمالك فقط');
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
                      _showLogoutDialog(context);
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
