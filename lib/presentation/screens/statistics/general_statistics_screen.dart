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

class GeneralStatisticsScreen extends StatefulWidget {
  const GeneralStatisticsScreen({super.key});

  @override
  State<GeneralStatisticsScreen> createState() =>
      _GeneralStatisticsScreenState();
}

class _GeneralStatisticsScreenState extends State<GeneralStatisticsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

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
    final provider = context.read<StatisticsProvider>();
    final localStartDate = _startDate;

    if (localStartDate != null) {
      var localEndDate = _endDate ?? localStartDate;

      if (localEndDate.isBefore(localStartDate)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تاريخ النهاية لا يمكن أن يكون قبل تاريخ البداية')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات العامة'),
        centerTitle: true,
      ),
      body: Consumer<StatisticsProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildDateFilter(provider),
              const Divider(height: 1),
              Expanded(
                child: _buildContent(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(StatisticsProvider provider) {
    if (provider.isLoading) {
      return const LoadingIndicator(message: 'جاري تحميل الإحصائيات...');
    }
    if (provider.errorMessage != null) {
      return CustomErrorWidget(message: provider.errorMessage!);
    }

    if (provider.mode == StatsMode.filtered) {
      if (provider.filteredStats != null) {
        return _buildStatistics(
            context, StatsSummaryModel.fromMap(provider.filteredStats!));
      } else {
        return _buildEmptyState(isCustom: true);
      }
    } else {
      // Dashboard mode
      if (provider.dashboardSummary != null) {
        return _buildStatistics(context, provider.dashboardSummary!);
      } else {
        return _buildEmptyState();
      }
    }
  }

  Widget _buildDateFilter(StatisticsProvider provider) {
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
                      ? 'تاريخ البداية'
                      : DateHelper.formatDateTime(_startDate!)),
                  onPressed: () => _selectDate(context, true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_endDate == null
                      ? 'تاريخ النهاية'
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
                  text: 'تطبيق الفلتر',
                  onPressed: _startDate == null ? null : _applyFilter,
                  size: ButtonSize.small,
                ),
              ),
              if (provider.mode == StatsMode.filtered) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: CustomButton(
                    text: 'مسح الفلتر',
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
  }

  Widget _buildEmptyState({bool isCustom = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined,
              size: 80, color: AppColors.textSecondary(context)),
          const SizedBox(height: 16),
          Text(isCustom
              ? 'لا توجد بيانات في هذا النطاق الزمني.'
              : 'لا توجد إحصائيات لعرضها.'),
        ],
      ),
    );
  }

  Widget _buildStatistics(BuildContext context, StatsSummaryModel stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBalanceSection(context, stats),
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
    );
  }

  Widget _buildBalanceSection(BuildContext context, StatsSummaryModel stats) {
    final totalBalance = stats.totalBalance;

    return _buildStatCard(
      context: context,
      icon: Icons.account_balance_wallet_outlined,
      title: 'الرصيد',
      color: Colors.teal,
      children: [
        _StatItem(
          context: context,
          label: 'إجمالي الرصيد في المحافظ',
          value: NumberFormatter.formatAmount(totalBalance),
        ),
      ],
    );
  }

  Widget _buildTransactionsSection(
      BuildContext context, StatsSummaryModel stats) {
    return _buildStatCard(
      context: context,
      icon: Icons.swap_horiz,
      title: 'المعاملات',
      color: Colors.blueGrey,
      children: [
        _StatItem(
          context: context,
          label: 'إجمالي المعاملات',
          value: NumberFormatter.formatNumber(stats.totalTransactions),
        ),
        _StatItem(
          context: context,
          label: 'معاملات الإرسال',
          value: NumberFormatter.formatNumber(stats.sendCount),
          valueColor: AppColors.send,
        ),
        _StatItem(
          context: context,
          label: 'معاملات الاستقبال',
          value: NumberFormatter.formatNumber(stats.receiveCount),
          valueColor: AppColors.receive,
        ),
      ],
    );
  }

  Widget _buildAmountsSection(BuildContext context, StatsSummaryModel stats) {
    return _buildStatCard(
      context: context,
      icon: Icons.monetization_on_outlined,
      title: 'المبالغ',
      color: Colors.purple,
      children: [
        _StatItem(
          context: context,
          label: 'إجمالي مبلغ الإرسال',
          value: NumberFormatter.formatAmount(stats.totalSentAmount),
          valueColor: AppColors.send,
        ),
        _StatItem(
          context: context,
          label: 'إجمالي مبلغ الاستقبال',
          value: NumberFormatter.formatAmount(stats.totalReceivedAmount),
          valueColor: AppColors.receive,
        ),
        const Divider(height: 10),
        _StatItem(
          context: context,
          label: 'المبلغ الإجمالي',
          value: NumberFormatter.formatAmount(
              stats.totalSentAmount + stats.totalReceivedAmount),
        ),
      ],
    );
  }

  Widget _buildCommissionSection(
      BuildContext context, StatsSummaryModel stats) {
    final totalCommission = stats.totalCommission;
    final totalTransactions = stats.totalTransactions;
    final averageCommission =
        totalTransactions > 0 ? totalCommission / totalTransactions : 0.0;
    return _buildStatCard(
      context: context,
      icon: Icons.attach_money,
      title: 'العمولات',
      color: AppColors.success,
      children: [
        _StatItem(
          context: context,
          label: 'إجمالي العمولات',
          value: NumberFormatter.formatAmount(totalCommission),
        ),
        _StatItem(
          context: context,
          label: 'متوسط العمولة للمعاملة',
          value: NumberFormatter.formatAmount(averageCommission),
        ),
      ],
    );
  }

  Widget _buildDebtsSection(BuildContext context, StatsSummaryModel stats) {
    return _buildStatCard(
      context: context,
      icon: Icons.credit_card_off_outlined,
      title: 'الديون',
      color: AppColors.error,
      children: [
        _StatItem(
          context: context,
          label: 'الديون المفتوحة',
          value: NumberFormatter.formatNumber(stats.openDebtsCount),
          subtitle: NumberFormatter.formatAmount(stats.totalOpenAmount),
        ),
        _StatItem(
          context: context,
          label: 'الديون المسددة',
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

  Widget _StatItem({
    required BuildContext context,
    required String label,
    required String value,
    String? subtitle,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodyLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary(context))),
              ],
            ],
          ),
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
