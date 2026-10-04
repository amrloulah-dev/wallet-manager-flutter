import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../data/models/user_permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class UserPermissionsWidget extends StatefulWidget {
  final UserPermissions initialPermissions;
  final ValueChanged<UserPermissions> onPermissionsChanged;

  const UserPermissionsWidget({
    super.key,
    required this.initialPermissions,
    required this.onPermissionsChanged,
  });

  @override
  State<UserPermissionsWidget> createState() => _UserPermissionsWidgetState();
}

class _UserPermissionsWidgetState extends State<UserPermissionsWidget> {
  late UserPermissions _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = widget.initialPermissions;
  }

  void _updatePermission(UserPermissions newPermissions) {
    setState(() {
      _permissions = newPermissions;
    });
    widget.onPermissionsChanged(_permissions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.employeePermissions,
            style: AppTextStyles.h3),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.defineEmployeeActions,
          style: AppTextStyles.bodySmall
              .copyWith(color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: AppLocalizations.of(context)!.financialTransactionsSection,
          icon: Icons.receipt_long_outlined,
          children: [
            _buildSwitch(
              AppLocalizations.of(context)!.createNewTransaction,
              _permissions.createTransaction,
              (val) => _updatePermission(
                  _permissions.copyWith(createTransaction: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.viewAllTransactions,
              _permissions.viewAllTransactions,
              (val) => _updatePermission(
                  _permissions.copyWith(viewAllTransactions: val)),
            ),
          ],
        ),
        _buildSection(
          title: AppLocalizations.of(context)!.debtsSection,
          icon: Icons.money_off_outlined,
          children: [
            _buildSwitch(
              AppLocalizations.of(context)!.viewDebtsList,
              _permissions.viewDebts,
              (val) => _updatePermission(_permissions.copyWith(viewDebts: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.addNewDebtPermission,
              _permissions.createDebt,
              (val) =>
                  _updatePermission(_permissions.copyWith(createDebt: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.collectDebt,
              _permissions.collectDebt,
              (val) =>
                  _updatePermission(_permissions.copyWith(collectDebt: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.deleteDebtPermission,
              _permissions.deleteDebt,
              (val) =>
                  _updatePermission(_permissions.copyWith(deleteDebt: val)),
            ),
          ],
        ),
        _buildSection(
          title: AppLocalizations.of(context)!.walletsSection,
          icon: Icons.account_balance_wallet_outlined,
          children: [
            _buildSwitch(
              AppLocalizations.of(context)!.viewWalletsList,
              _permissions.viewWallets,
              (val) =>
                  _updatePermission(_permissions.copyWith(viewWallets: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.addNewWalletPermission,
              _permissions.createWallet,
              (val) =>
                  _updatePermission(_permissions.copyWith(createWallet: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.addBalanceToWalletPermission,
              _permissions.addBalance,
              (val) =>
                  _updatePermission(_permissions.copyWith(addBalance: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.editWalletData,
              _permissions.editWallet,
              (val) =>
                  _updatePermission(_permissions.copyWith(editWallet: val)),
            ),
            _buildSwitch(
              AppLocalizations.of(context)!.viewWalletBalance,
              _permissions.viewWalletBalance,
              (val) => _updatePermission(
                  _permissions.copyWith(viewWalletBalance: val)),
            ),
          ],
        ),
        _buildSection(
          title: AppLocalizations.of(context)!.dashboardSection,
          icon: Icons.dashboard_outlined,
          children: [
            _buildSwitch(
              AppLocalizations.of(context)!.viewStatsCharts,
              _permissions.viewDashboardStats,
              (val) => _updatePermission(
                  _permissions.copyWith(viewDashboardStats: val)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.border(context)),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title, style: AppTextStyles.bodyLarge),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          children: children,
        ),
      ),
    );
  }

  Widget _buildSwitch(
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title, style: AppTextStyles.bodyMedium),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      dense: true,
    );
  }
}
