import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/date_helper.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../providers/wallet_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../../data/repositories/wallet_repository.dart';
import '../../widgets/wallet/wallet_limit_bar.dart';
import '../../widgets/wallet/wallet_stats_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class WalletDetailsScreen extends StatefulWidget {
  const WalletDetailsScreen({super.key});

  @override
  State<WalletDetailsScreen> createState() => _WalletDetailsScreenState();
}

class _WalletDetailsScreenState extends State<WalletDetailsScreen> {
  String? _walletId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _walletId ??= ModalRoute.of(context)?.settings.arguments as String?;
  }

  @override
  Widget build(BuildContext context) {
    if (_walletId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.error)),
        body: CustomErrorWidget(
            message: AppLocalizations.of(context)!.noWalletSelected),
      );
    }

    return StreamBuilder<WalletModel?>(
      stream: WalletRepository().watchWallet(_walletId!),
      builder: (context, snapshot) {
        final wallet = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.walletDetails),
            centerTitle: true,
            actions: wallet != null
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _navigateToEditWallet(context, wallet),
                      tooltip: AppLocalizations.of(context)!.edit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _showDeleteDialog(wallet),
                      tooltip: AppLocalizations.of(context)!.delete,
                    ),
                  ]
                : [],
          ),
          body: _buildBody(context, snapshot),
          floatingActionButton: wallet != null
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      _navigateToCreateTransaction(context, wallet),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.newTransaction),
                )
              : null,
        );
      },
    );
  }

  Widget _buildBody(
      BuildContext context, AsyncSnapshot<WalletModel?> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return LoadingIndicator(
          message: AppLocalizations.of(context)!.loadingWalletData);
    }

    if (snapshot.hasError) {
      return CustomErrorWidget(
        message: AppLocalizations.of(context)!.errorLoadingData,
        onRetry: () => setState(() {}),
      );
    }

    final wallet = snapshot.data;

    if (wallet == null) {
      return CustomErrorWidget(
        message: AppLocalizations.of(context)!.walletNotFound,
        onRetry: () => Navigator.of(context).pop(),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        return Future.delayed(const Duration(seconds: 1));
      },
      color: AppColors.primary,
      backgroundColor: Colors.white,
      strokeWidth: 2.5,
      edgeOffset: 0,
      displacement: 30,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: (notification) {
          notification.disallowIndicator();
          return true;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'wallet_${wallet.walletId}',
                child: Material(
                  type: MaterialType.transparency,
                  child: _buildBasicInfoCard(context, wallet),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.sendLimits),
              _buildSendLimitsCard(wallet),
              const SizedBox(height: 24),
              _buildSectionTitle(AppLocalizations.of(context)!.receiveLimits),
              _buildReceiveLimitsCard(wallet),
              const SizedBox(height: 24),
              WalletStatsCard(stats: wallet.stats),
              const SizedBox(height: 80), // Space for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(BuildContext context, WalletModel wallet) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(wallet.walletTypeIcon, size: 32, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        NumberFormatter.formatPhoneNumber(wallet.phoneNumber),
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.phoneNumber,
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textSecondary(context)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              context: context,
              icon: Icons.account_balance,
              label: AppLocalizations.of(context)!.currentBalance,
              value: NumberFormatter.formatAmount(wallet.balance),
              valueStyle: AppTextStyles.h2.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              context: context,
              icon: Icons.account_balance_wallet_outlined,
              label: AppLocalizations.of(context)!.walletType,
              value: wallet.walletTypeDisplayName,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.label_outline,
              label: AppLocalizations.of(context)!.walletStatus,
              value: wallet.walletStatusDisplayName,
              valueColor: wallet.walletStatus == 'new'
                  ? AppColors.newWallet
                  : AppColors.oldWallet,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.calendar_today_outlined,
              label: AppLocalizations.of(context)!.addedDate,
              value: DateHelper.formatTimestamp(wallet.createdAt),
            ),
            if (wallet.notes != null && wallet.notes!.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow(
                context: context,
                icon: Icons.note_outlined,
                label: AppLocalizations.of(context)!.notes,
                value: wallet.notes!,
                maxLines: 5,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    TextStyle? valueStyle,
    Color? valueColor,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary(context)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary(context))),
              const SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ??
                    AppTextStyles.bodyLarge.copyWith(
                        color: valueColor, fontWeight: FontWeight.w500),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
      child: Text(title, style: AppTextStyles.h3),
    );
  }

  Widget _buildSendLimitsCard(WalletModel wallet) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            WalletLimitBar(
              label: AppLocalizations.of(context)!.dailyLimitSimple,
              used: wallet.sendLimits.dailyUsed,
              limit: wallet.sendLimits.dailyLimit,
              percentage: wallet.sendLimits.dailyPercentage,
              warningLevel: wallet.sendDailyWarningLevel,
            ),
            const SizedBox(height: 20),
            WalletLimitBar(
              label: AppLocalizations.of(context)!.monthlyLimitSimple,
              used: wallet.sendLimits.monthlyUsed,
              limit: wallet.sendLimits.monthlyLimit,
              percentage: wallet.sendLimits.monthlyPercentage,
              warningLevel: wallet.sendMonthlyWarningLevel,
            ),
            if (wallet.sendLimits.isDailyLimitReached ||
                wallet.sendLimits.isMonthlyLimitReached) ...[
              const SizedBox(height: 16),
              _buildLimitReachedWarning(
                  AppLocalizations.of(context)!.sendLimitReachedMessage),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveLimitsCard(WalletModel wallet) {
    // Assuming receive limits have warning levels in the model, otherwise default to 'green'
    final dailyReceiveWarningLevel = 'green';
    final monthlyReceiveWarningLevel = 'green';

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            WalletLimitBar(
              label: AppLocalizations.of(context)!.dailyLimitSimple,
              used: wallet.receiveLimits.dailyUsed,
              limit: wallet.receiveLimits.dailyLimit,
              percentage: wallet.receiveLimits.dailyPercentage,
              warningLevel: dailyReceiveWarningLevel,
            ),
            const SizedBox(height: 20),
            WalletLimitBar(
              label: AppLocalizations.of(context)!.monthlyLimitSimple,
              used: wallet.receiveLimits.monthlyUsed,
              limit: wallet.receiveLimits.monthlyLimit,
              percentage: wallet.receiveLimits.monthlyPercentage,
              warningLevel: monthlyReceiveWarningLevel,
            ),
            if (wallet.receiveLimits.isDailyLimitReached ||
                wallet.receiveLimits.isMonthlyLimitReached) ...[
              const SizedBox(height: 16),
              _buildLimitReachedWarning(
                  AppLocalizations.of(context)!.receiveLimitReachedMessage),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLimitReachedWarning(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToEditWallet(BuildContext context, WalletModel wallet) {
    Navigator.pushNamed(context, RouteConstants.walletForm, arguments: wallet);
  }

  void _navigateToCreateTransaction(BuildContext context, WalletModel wallet) {
    Navigator.pushNamed(context, RouteConstants.createTransaction,
        arguments: wallet.walletId);
  }

  void _showDeleteDialog(WalletModel wallet) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.confirmDeletion,
      message: AppLocalizations.of(context)!.deleteWalletConfirmationDetailed(
          NumberFormatter.formatPhoneNumber(wallet.phoneNumber)),
      confirmText: AppLocalizations.of(context)!.delete,
      type: DialogType.danger,
    );

    if (confirmed == true) {
      final walletProvider = context.read<WalletProvider>();
      final navigator = Navigator.of(context);

      final success = await walletProvider.deleteWallet(wallet.walletId);

      if (!mounted) return;

      if (success) {
        ToastUtils.showSuccess(
            AppLocalizations.of(context)!.walletDeletedSuccessfully);
        navigator.pop(); // Go back from details screen
      } else {
        ToastUtils.showError(walletProvider.errorMessage ??
            AppLocalizations.of(context)!.walletDeletionFailed);
      }
    }
  }
}
