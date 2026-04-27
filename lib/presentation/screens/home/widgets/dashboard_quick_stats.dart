import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/stats_summary_model.dart';
import '../../../../data/models/daily_stats_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/route_constants.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../providers/statistics_provider.dart';
import '../../../../providers/auth_provider.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../widgets/common/skeleton_card.dart';
import '../../../widgets/dashboard/stats_card.dart';
import '../../../../core/enums/user_enums.dart';

class DashboardQuickStats extends StatelessWidget {
  const DashboardQuickStats({super.key});

  @override
  Widget build(BuildContext context) {
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

          final lastUpdated = stats.lastUpdated;
          final formattedTime = lastUpdated != null
              ? DateFormat.yMMMd().add_jm().format(lastUpdated)
              : 'N/A';

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
                            final canAccess = user?.role == UserRole.owner || // ENUM refactor
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
                        value: (data.today?.transactionCount ?? 0).toString(),
                        icon: Icons.swap_horiz,
                        color: Colors.green.shade700,
                        onTap: () {
                          final user = context.read<AuthProvider>().currentUser;
                          if (user != null &&
                              (user.role == UserRole.owner || // ENUM refactor
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
                        value: NumberFormatter.formatAmount(data.today?.totalCommission),
                        icon: Icons.attach_money,
                        color: Colors.orange.shade800,
                        onTap: () {
                          final user = context.read<AuthProvider>().currentUser;
                          if (user != null &&
                              (user.role == UserRole.owner || // ENUM refactor
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
                          final canAccess = user?.role == UserRole.owner || // ENUM refactor
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
}
