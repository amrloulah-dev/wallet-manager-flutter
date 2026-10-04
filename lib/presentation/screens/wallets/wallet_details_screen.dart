import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/date_helper.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/platform_settings_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../utils/wallet_extensions.dart';
import '../../widgets/wallet/wallet_limit_bar.dart';
import '../../widgets/wallet/wallet_stats_card.dart';
import '../../widgets/common/error_widget.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../core/enums/wallet_enums.dart';

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

    return Selector<WalletProvider, WalletModel?>(
      selector: (context, provider) => provider.walletMap[_walletId!],
      builder: (context, wallet, child) {
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
          body: _buildBody(context, wallet),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, WalletModel? wallet) {
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
              value: AppLocalizations.of(context)!
                  .getWalletTypeName(wallet.walletType),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.label_outline,
              label: AppLocalizations.of(context)!.walletStatus,
              value: AppLocalizations.of(context)!
                  .getWalletStatusName(wallet.walletStatus),
              valueColor: wallet.walletStatus ==
                      WalletStatus
                          .suspended // ENUM refactor (placeholder check)
                  ? AppColors.error
                  : AppColors.primary,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.calendar_today_outlined,
              label: AppLocalizations.of(context)!.addedDate,
              value:
                  DateHelper.formatDateTime(wallet.createdAt ?? DateTime.now()),
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
      padding: const EdgeInsetsDirectional.only(bottom: 8.0, end: 8.0),
      child: Text(title, style: AppTextStyles.h3),
    );
  }

  Widget _buildSendLimitsCard(WalletModel wallet) {
    final settings =
        Provider.of<PlatformSettingsProvider>(context, listen: false).settings;
    final dynamicLimits = wallet.getDynamicNetworkLimits(settings);
    final limits = wallet.getLimits();

    final double sendDailyPercentage = dynamicLimits.dailySend > 0
        ? (limits.dailyUsed / dynamicLimits.dailySend * 100).clamp(0.0, 100.0)
        : 0.0;
    final double sendMonthlyPercentage = dynamicLimits.monthlySend > 0
        ? (limits.monthlyUsed / dynamicLimits.monthlySend * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    String getWarningLevel(double percentage) {
      if (percentage >= 90) return 'red';
      if (percentage >= 70) return 'yellow';
      return 'green';
    }

    final dailySendWarningLevel = getWarningLevel(sendDailyPercentage);
    final monthlySendWarningLevel = getWarningLevel(sendMonthlyPercentage);

    final bool isDailyLimitReached =
        limits.dailyUsed >= dynamicLimits.dailySend;
    final bool isMonthlyLimitReached =
        limits.monthlyUsed >= dynamicLimits.monthlySend;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            WalletLimitBar(
              label: AppLocalizations.of(context)!.dailyLimitSimple,
              used: limits.dailyUsed,
              limit: dynamicLimits.dailySend,
              percentage: sendDailyPercentage,
              warningLevel: dailySendWarningLevel,
            ),
            const SizedBox(height: 20),
            WalletLimitBar(
              label: AppLocalizations.of(context)!.monthlyLimitSimple,
              used: limits.monthlyUsed,
              limit: dynamicLimits.monthlySend,
              percentage: sendMonthlyPercentage,
              warningLevel: monthlySendWarningLevel,
            ),
            if (isDailyLimitReached || isMonthlyLimitReached) ...[
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
    final settings =
        Provider.of<PlatformSettingsProvider>(context, listen: false).settings;
    final dynamicLimits = wallet.getDynamicNetworkLimits(settings);
    final limits = wallet.getReceiveLimits();

    final double receiveDailyPercentage = dynamicLimits.dailyReceive > 0
        ? (limits.dailyUsed / dynamicLimits.dailyReceive * 100)
            .clamp(0.0, 100.0)
        : 0.0;
    final double receiveMonthlyPercentage = dynamicLimits.monthlyReceive > 0
        ? (limits.monthlyUsed / dynamicLimits.monthlyReceive * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    String getWarningLevel(double percentage) {
      if (percentage >= 90) return 'red';
      if (percentage >= 70) return 'yellow';
      return 'green';
    }

    final dailyReceiveWarningLevel = getWarningLevel(receiveDailyPercentage);
    final monthlyReceiveWarningLevel =
        getWarningLevel(receiveMonthlyPercentage);

    final bool isDailyLimitReached =
        limits.dailyUsed >= dynamicLimits.dailyReceive;
    final bool isMonthlyLimitReached =
        limits.monthlyUsed >= dynamicLimits.monthlyReceive;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            WalletLimitBar(
              label: AppLocalizations.of(context)!.dailyLimitSimple,
              used: limits.dailyUsed,
              limit: dynamicLimits.dailyReceive,
              percentage: receiveDailyPercentage,
              warningLevel: dailyReceiveWarningLevel,
            ),
            const SizedBox(height: 20),
            WalletLimitBar(
              label: AppLocalizations.of(context)!.monthlyLimitSimple,
              used: limits.monthlyUsed,
              limit: dynamicLimits.monthlyReceive,
              percentage: receiveMonthlyPercentage,
              warningLevel: monthlyReceiveWarningLevel,
            ),
            if (isDailyLimitReached || isMonthlyLimitReached) ...[
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
        color: AppColors.error.withAlpha(26),
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
    if (context.read<AuthProvider>().isSubscriptionExpired) {
      ToastUtils.showError(AppLocalizations.of(context)!.subscriptionExpired);
      return;
    }
    Navigator.pushNamed(context, RouteConstants.walletForm, arguments: wallet);
  }

  void _showDeleteDialog(WalletModel wallet) async {
    if (context.read<AuthProvider>().isSubscriptionExpired) {
      ToastUtils.showError(AppLocalizations.of(context)!.subscriptionExpired);
      return;
    }
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.confirmDeletion,
      message: AppLocalizations.of(context)!.deleteWalletConfirmationDetailed(
          NumberFormatter.formatPhoneNumber(wallet.phoneNumber)),
      confirmText: AppLocalizations.of(context)!.delete,
      type: DialogType.danger,
    );

    if (!mounted) return;

    if (confirmed == true) {
      final walletProvider = context.read<WalletProvider>();
      final localizations = AppLocalizations.of(context)!;
      final navigator = Navigator.of(context);

      final success = await walletProvider.deleteWallet(wallet.walletId);

      if (!mounted) return;

      if (success) {
        ToastUtils.showSuccess(localizations.walletDeletedSuccessfully);
        navigator.pop(); // Go back from details screen
      } else {
        ToastUtils.showError(
            walletProvider.errorMessage ?? localizations.walletDeletionFailed);
      }
    }
  }
}
