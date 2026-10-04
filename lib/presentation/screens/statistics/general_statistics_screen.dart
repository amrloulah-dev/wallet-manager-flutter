import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/data/models/stats_summary_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/statistics_provider.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../../l10n/arb/app_localizations.dart';

class GeneralStatisticsScreen extends StatefulWidget {
  const GeneralStatisticsScreen({super.key});

  @override
  State<GeneralStatisticsScreen> createState() =>
      _GeneralStatisticsScreenState();
}

class _GeneralStatisticsScreenState extends State<GeneralStatisticsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    // Auto-fetch dashboard stats on initial screen mount if not present in memory
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final provider = context.read<StatisticsProvider>();
        if (provider.dashboardSummary == null) {
          provider.fetchDashboardStats();
        }
      }
    });
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final initialDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    final firstDate = DateTime(2020);
    final lastDate = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = pickedDate;
        }
      });
    }
  }

  void _applyFilter() {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<StatisticsProvider>();
    final localStartDate = _startDate;

    if (localStartDate != null) {
      var localEndDate = _endDate ?? localStartDate;

      if (localEndDate.isBefore(localStartDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.filterDateError)),
        );
        return;
      }

      // Adjust the end date to include the entire day
      localEndDate = DateTime(
          localEndDate.year, localEndDate.month, localEndDate.day, 23, 59, 59);

      provider.fetchFilteredStats(
          DateTimeRange(start: localStartDate, end: localEndDate));
    }
  }

  void _clearFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    context.read<StatisticsProvider>().clearFilteredStats();
  }

  /// On-demand manual network refresh handler for RefreshIndicator
  Future<void> _refreshStats() async {
    final provider = context.read<StatisticsProvider>();
    if (provider.mode == StatsMode.filtered && _startDate != null) {
      final localStartDate = _startDate!;
      var localEndDate = _endDate ?? localStartDate;
      localEndDate = DateTime(localEndDate.year, localEndDate.month,
          localEndDate.day, 23, 59, 59);
      await provider.fetchFilteredStats(
          DateTimeRange(start: localStartDate, end: localEndDate));
    } else {
      await provider.fetchDashboardStats(forceRefresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.generalStats),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildDateFilter(),
          const Divider(height: 1),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    return Selector<StatisticsProvider, bool>(
      selector: (context, provider) => provider.isLoading,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return LoadingIndicator(message: l10n.loadingWalletData);
        }

        return Selector<StatisticsProvider, String?>(
          selector: (context, provider) => provider.errorMessage,
          builder: (context, errorMessage, child) {
            if (errorMessage != null) {
              final l10n = AppLocalizations.of(context)!;
              String displayMessage;

              // Resolve localization keys
              switch (errorMessage) {
                case 'stats_error_summary_fetch':
                  displayMessage = l10n.stats_error_summary_fetch;
                  break;
                case 'stats_error_today_fetch':
                  displayMessage = l10n.stats_error_today_fetch;
                  break;
                case 'stats_error_filtered_fetch':
                  displayMessage = l10n.stats_error_filtered_fetch;
                  break;
                case 'stats_error_init_failed':
                  displayMessage = l10n.stats_error_init_failed;
                  break;
                default:
                  displayMessage = errorMessage;
              }

              return CustomErrorWidget(message: displayMessage);
            }

            return Selector<StatisticsProvider, StatsMode>(
              selector: (context, provider) => provider.mode,
              builder: (context, mode, child) {
                if (mode == StatsMode.filtered) {
                  return Selector<StatisticsProvider, Map<String, dynamic>?>(
                    selector: (context, provider) => provider.filteredStats,
                    builder: (context, filteredStats, child) {
                      if (filteredStats != null) {
                        return _buildStatistics(
                            context, StatsSummaryModel.fromMap(filteredStats));
                      } else {
                        return _buildEmptyState(isCustom: true);
                      }
                    },
                  );
                } else {
                  // Dashboard mode
                  return Selector<StatisticsProvider, StatsSummaryModel?>(
                    selector: (context, provider) => provider.dashboardSummary,
                    builder: (context, dashboardSummary, child) {
                      if (dashboardSummary != null) {
                        return _buildStatistics(context, dashboardSummary);
                      } else {
                        return _buildEmptyState();
                      }
                    },
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDateFilter() {
    final l10n = AppLocalizations.of(context)!;
    return Selector<StatisticsProvider, StatsMode>(
      selector: (context, provider) => provider.mode,
      builder: (context, mode, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_startDate == null
                          ? l10n.startDate
                          : DateHelper.formatDateTime(_startDate!)),
                      onPressed: () => _selectDate(context, true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_endDate == null
                          ? l10n.endDate
                          : DateHelper.formatDateTime(_endDate!)),
                      onPressed: () => _selectDate(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: l10n.applyFilter,
                      onPressed: _startDate == null ? null : _applyFilter,
                      size: ButtonSize.small,
                    ),
                  ),
                  if (mode == StatsMode.filtered) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomButton(
                        text: l10n.clearFilter,
                        onPressed: _clearFilter,
                        type: ButtonType.outlined,
                        size: ButtonSize.small,
                      ),
                    ),
                  ]
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({bool isCustom = false}) {
    final l10n = AppLocalizations.of(context)!;
    return RefreshIndicator(
      onRefresh: _refreshStats,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_outlined,
                      size: 80, color: AppColors.textSecondary(context)),
                  const SizedBox(height: 16),
                  Text(isCustom ? l10n.noDataInRange : l10n.noStatsToShow),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatistics(BuildContext context, StatsSummaryModel stats) {
    return RefreshIndicator(
      onRefresh: _refreshStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBalanceSection(context),
            const SizedBox(height: 20),
            _buildTransactionsSection(context, stats),
            const SizedBox(height: 20),
            _buildAmountsSection(context, stats),
            const SizedBox(height: 20),
            _buildCommissionSection(context, stats),
            const SizedBox(height: 20),
            _buildDebtsSection(context, stats),
          ],
        ),
      ),
    );
  }

  /// Reactive Total Balance Card: Wrapped in a fine-grained Selector
  /// to reactively re-render whenever provider.dashboardSummary.totalBalance changes
  /// in RAM (optimistic updates, overlay submissions, or network syncs).
  Widget _buildBalanceSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Selector<StatisticsProvider, double>(
      selector: (_, provider) => provider.dashboardSummary?.totalBalance ?? 0.0,
      builder: (context, totalBalance, child) {
        return _buildStatCard(
          context: context,
          icon: Icons.account_balance_wallet_outlined,
          title: l10n.balance,
          color: Colors.teal,
          children: [
            StatItemWidget(
              label: l10n.totalWalletBalance,
              value: NumberFormatter.formatAmount(totalBalance),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionsSection(
      BuildContext context, StatsSummaryModel stats) {
    final l10n = AppLocalizations.of(context)!;
    return _buildStatCard(
      context: context,
      icon: Icons.swap_horiz,
      title: l10n.transactions,
      color: Colors.blueGrey,
      children: [
        StatItemWidget(
          label: l10n.totalTransactions,
          value: NumberFormatter.formatNumber(stats.totalTransactions),
        ),
        StatItemWidget(
          label: l10n.sendTransactions,
          value: NumberFormatter.formatNumber(stats.sendCount),
          valueColor: AppColors.send,
        ),
        StatItemWidget(
          label: l10n.receiveTransactions,
          value: NumberFormatter.formatNumber(stats.receiveCount),
          valueColor: AppColors.receive,
        ),
      ],
    );
  }

  Widget _buildAmountsSection(BuildContext context, StatsSummaryModel stats) {
    final l10n = AppLocalizations.of(context)!;
    return _buildStatCard(
      context: context,
      icon: Icons.monetization_on_outlined,
      title: l10n.amounts,
      color: Colors.purple,
      children: [
        StatItemWidget(
          label: l10n.sendAmount,
          value: NumberFormatter.formatAmount(stats.totalSentAmount),
          valueColor: AppColors.send,
        ),
        StatItemWidget(
          label: l10n.receiveAmount,
          value: NumberFormatter.formatAmount(stats.totalReceivedAmount),
          valueColor: AppColors.receive,
        ),
        const Divider(height: 10),
        StatItemWidget(
          label: l10n.totalAmountCombined,
          value: NumberFormatter.formatAmount(
              stats.totalSentAmount + stats.totalReceivedAmount),
        ),
      ],
    );
  }

  Widget _buildCommissionSection(
      BuildContext context, StatsSummaryModel stats) {
    final l10n = AppLocalizations.of(context)!;
    final totalCommission = stats.totalCommission;
    final totalTransactions = stats.totalTransactions;
    final averageCommission =
        totalTransactions > 0 ? totalCommission / totalTransactions : 0.0;
    return _buildStatCard(
      context: context,
      icon: Icons.attach_money,
      title: l10n.commission,
      color: AppColors.success,
      children: [
        StatItemWidget(
          label: l10n.totalCommissionLabel,
          value: NumberFormatter.formatAmount(totalCommission),
        ),
        StatItemWidget(
          label: l10n.averageCommission,
          value: NumberFormatter.formatAmount(averageCommission),
        ),
      ],
    );
  }

  Widget _buildDebtsSection(BuildContext context, StatsSummaryModel stats) {
    final l10n = AppLocalizations.of(context)!;
    return _buildStatCard(
      context: context,
      icon: Icons.credit_card_off_outlined,
      title: l10n.debts,
      color: AppColors.error,
      children: [
        StatItemWidget(
          label: l10n.openDebtsLabel,
          value: NumberFormatter.formatNumber(stats.openDebtsCount),
          subtitle: NumberFormatter.formatAmount(stats.totalOpenAmount),
        ),
        StatItemWidget(
          label: l10n.paidDebtsLabel,
          value: NumberFormatter.formatNumber(stats.paidDebtsCount),
          subtitle: NumberFormatter.formatAmount(stats.totalPaidAmount),
          valueColor: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.h3.copyWith(color: color)),
              ],
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

class StatItemWidget extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const StatItemWidget({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary(context)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: AppTextStyles.h3
                .copyWith(color: valueColor ?? AppColors.textPrimary(context)),
          ),
        ],
      ),
    );
  }
}
