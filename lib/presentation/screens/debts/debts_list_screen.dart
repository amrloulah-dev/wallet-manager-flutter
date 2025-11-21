import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';
import 'package:walletmanager/core/utils/permission_helper.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/presentation/widgets/debt/partial_payment_bottom_sheet.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_constants.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/debt/debt_card.dart';
import '../../widgets/debt/debt_summary_card.dart';
import 'package:walletmanager/presentation/widgets/common/skeleton_list.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class DebtsListScreen extends StatefulWidget {
  const DebtsListScreen({super.key});

  @override
  State<DebtsListScreen> createState() => _DebtsListScreenState();
}

class _DebtsListScreenState extends State<DebtsListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DebtProvider>().fetchInitialDebts();
    });

    // Add listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      context.read<DebtProvider>().fetchMoreDebts();
    }
  }

  void _navigateToAddDebt(BuildContext context) {
    if (PermissionHelper.canCreateDebt(context, showMessage: true)) {
      Navigator.pushNamed(context, RouteConstants.addDebt);
    }
  }

  Future<void> _showMarkPaidDialog(DebtModel debt) async {
    final bool? confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: 'تسديد الدين',
      message: 'هل أنت متأكد أنك تريد تسجيل هذا الدين كـ "مسدد"؟',
      confirmText: 'تأكيد التسديد',
    );

    if (confirmed == true) {
      final debtProvider = context.read<DebtProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUserId;

      if (currentUserId == null) {
        ToastUtils.showError('خطأ: المستخدم غير مسجل');
        return;
      }

      final success = await debtProvider.payPartialDebt(debt.debtId, debt.amountDue, currentUserId);

      if (mounted && !success) {
        ToastUtils.showError(debtProvider.errorMessage ?? 'فشل تسديد الدين');
      } else {
        ToastUtils.showSuccess('تم تسديد الدين بنجاح');
      }
    }
  }

  void _showPartialPaymentSheet(BuildContext context, DebtModel debt) {
    final debtProvider = context.read<DebtProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => ChangeNotifierProvider.value(
        value: debtProvider,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface(bottomSheetContext),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: PartialPaymentBottomSheet(debt: debt),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الديون'),
      ),
      body: Consumer<DebtProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              _buildSummarySection(provider),
              Expanded(
                child: _buildContent(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddDebt(context),
        icon: const Icon(Icons.add),
        label: const Text('إضافة دين'),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSummarySection(DebtProvider provider) {
    return Column(
      children: [
        DebtSummaryCard(
          openDebtsCount: provider.summary['openDebtsCount'] ?? 0,
          paidDebtsCount: provider.summary['paidDebtsCount'] ?? 0,
          totalOpenAmount: provider.summary['totalOpenAmount'] ?? 0.0,
          totalPaidAmount: provider.summary['totalPaidAmount'] ?? 0.0,
        ),
        _buildFilterTabs(context, provider.summary, provider),
      ],
    );
  }

  Widget _buildContent(DebtProvider provider) {
    if (provider.isLoading) {
      return const SkeletonList(itemCount: 5, itemHeight: 120);
    }

    if (provider.hasError) {
      return CustomErrorWidget(
        message: provider.errorMessage ?? 'حدث خطأ أثناء تحميل الديون.',
        onRetry: provider.fetchInitialDebts,
      );
    }

    if (provider.debts.isEmpty) {
      return EmptyStateWidget(
        message: 'لا توجد ديون مسجلة',
        description: 'سيتم عرض الديون المفتوحة والمسددة هنا.',
        icon: Icons.credit_card_off_outlined,
        actionText: 'إضافة دين جديد',
        onAction: () => _navigateToAddDebt(context),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.fetchInitialDebts,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80), // For FAB
        itemCount: provider.debts.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.debts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final debt = provider.debts[index];
          return DebtCard(
            key: ValueKey(debt.debtId),
            debt: debt,
            onTap: PermissionHelper.canMarkDebtPaid(context)
                ? () => _showPartialPaymentSheet(context, debt)
                : null,
            onMarkPaid: debt.isOpen && PermissionHelper.canMarkDebtPaid(context)
                ? () => _showMarkPaidDialog(debt) 
                : null,
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, Map<String, dynamic> summary, DebtProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _FilterChip(
              label: 'الكل (${summary['totalDebtsCount'] ?? 0})',
              isSelected: provider.currentFilter == 'all',
              onTap: () => provider.setFilter('all'),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: 'مفتوح (${summary['openDebtsCount'] ?? 0})',
              isSelected: provider.currentFilter == 'open',
              onTap: () => provider.setFilter('open'),
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FilterChip(
              label: 'مسدد (${summary['paidDebtsCount'] ?? 0})',
              isSelected: provider.currentFilter == 'paid',
              onTap: () => provider.setFilter('paid'),
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha((0.1 * 255).round()) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.divider(context),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: isSelected ? color : AppColors.textSecondary(context),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
