import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
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
import '../../../core/enums/debt_enums.dart';

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      context.read<DebtProvider>().fetchMoreDebts();
    }
  }

  void _navigateToAddDebt(BuildContext context) {
    if (PermissionHelper.canCreateDebt(context, showMessage: true)) {
      final currentType = context.read<DebtProvider>().currentDebtType;
      Navigator.pushNamed(
        context,
        RouteConstants.addDebt,
        arguments: currentType,
      );
    }
  }

  Future<void> _showMarkPaidDialog(DebtModel debt) async {
    final confirmed = await DialogUtils.showConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.settleDebt,
      message: AppLocalizations.of(context)!.settleDebtConfirmation,
      confirmText: AppLocalizations.of(context)!.confirmSettlement,
    );

    if (!mounted) return;

    if (confirmed == true) {
      final debtProvider = context.read<DebtProvider>();
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.currentUserId;

      if (currentUserId == null) {
        ToastUtils.showError(AppLocalizations.of(context)!.userNotRegistered);
        return;
      }

      final success = await debtProvider.payPartialDebt(
          debt.debtId, debt.amountDue, currentUserId);

      if (!mounted) return;

      if (!success) {
        ToastUtils.showError(debtProvider.errorMessage ??
            AppLocalizations.of(context)!.debtSettlementFailed);
      } else {
        ToastUtils.showSuccess(
            AppLocalizations.of(context)!.debtSettledSuccess);
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
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
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
        title: Text(AppLocalizations.of(context)!.debtsTitle),
      ),
      body: Column(
        children: [
          _buildSummarySection(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddDebt(context),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.addDebt),
        foregroundColor: Colors.white,
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Widget _buildSummarySection() {
    return Column(
      children: [
        _buildTypeSegmentControl(),
        const DebtSummaryCard(),
        _buildFilterTabs(context),
      ],
    );
  }

  Widget _buildContent() {
    return Consumer<DebtProvider>(
      builder: (context, provider, child) {
        final isLoading = provider.isLoading;
        final hasError = provider.errorMessage != null;
        final errorMessage = provider.errorMessage;
        final debts = provider.debts;
        final isLoadingMore = provider.isLoadingMore;

        if (isLoading) {
          return const SkeletonList(itemCount: 5, itemHeight: 120);
        }

        if (hasError) {
          return CustomErrorWidget(
            message:
                errorMessage ?? AppLocalizations.of(context)!.errorLoadingDebts,
            onRetry: provider.fetchInitialDebts,
          );
        }

        if (debts.isEmpty) {
          return EmptyStateWidget(
            message: AppLocalizations.of(context)!.noDebtsRecorded,
            description: AppLocalizations.of(context)!.debtsWillAppearHere,
            icon: Icons.credit_card_off_outlined,
            actionText: AppLocalizations.of(context)!.addNewDebt,
            onAction: () => _navigateToAddDebt(context),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.fetchInitialDebts,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: debts.length + (isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == debts.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final debt = debts[index];
              return DebtCard(
                key: ValueKey(
                    '${debt.debtId}_${debt.amountDue}_${debt.debtStatus}'),
                debt: debt,
                onTap: PermissionHelper.canMarkDebtPaid(context)
                    ? () => _showPartialPaymentSheet(context, debt)
                    : null,
                onMarkPaid:
                    debt.isOpen && PermissionHelper.canMarkDebtPaid(context)
                        ? () => _showMarkPaidDialog(debt)
                        : null,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    return Selector<DebtProvider, String>(
      selector: (context, provider) => provider.currentFilter,
      builder: (context, currentFilter, child) {
        return Selector<DebtProvider, Map<String, dynamic>>(
          selector: (context, provider) => provider.summary,
          builder: (context, summary, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _FilterChip(
                      label: AppLocalizations.of(context)!
                          .allWithCount(summary['totalDebtsCount'] ?? 0),
                      isSelected: currentFilter == 'all',
                      onTap: () =>
                          context.read<DebtProvider>().setFilter('all'),
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterChip(
                      label: AppLocalizations.of(context)!
                          .openWithCount(summary['openDebtsCount'] ?? 0),
                      isSelected: currentFilter == 'open',
                      onTap: () =>
                          context.read<DebtProvider>().setFilter('open'),
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterChip(
                      label: AppLocalizations.of(context)!
                          .paidWithCount(summary['paidDebtsCount'] ?? 0),
                      isSelected: currentFilter == 'paid',
                      onTap: () =>
                          context.read<DebtProvider>().setFilter('paid'),
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeSegmentControl() {
    return Selector<DebtProvider, DebtType>(
      // ENUM refactor
      selector: (context, provider) => provider.currentDebtType,
      builder: (context, currentDebtType, child) {
        return Container(
          margin: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TypeTab(
                  label: AppLocalizations.of(context)!.financialTransfers,
                  isSelected: currentDebtType == DebtType.transaction,
                  onTap: () => context
                      .read<DebtProvider>()
                      .setDebtType(DebtType.transaction),
                  icon: Icons.swap_horiz,
                ),
              ),
              Expanded(
                child: _TypeTab(
                  label: AppLocalizations.of(context)!.storeSales,
                  isSelected: currentDebtType == DebtType.storeSale,
                  onTap: () => context
                      .read<DebtProvider>()
                      .setDebtType(DebtType.storeSale),
                  icon: Icons.storefront_outlined,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color:
                  isSelected ? Colors.white : AppColors.textSecondary(context),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondary(context),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
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
          color: isSelected ? color.withAlpha(26) : Colors.transparent,
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
