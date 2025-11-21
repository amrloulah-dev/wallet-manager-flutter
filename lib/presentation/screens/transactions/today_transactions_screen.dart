import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/route_constants.dart';
import '../../../providers/transaction_provider.dart';
import '../../widgets/transaction/transaction_card.dart';
import '../../widgets/transaction/transaction_summary_card.dart';
import 'package:walletmanager/presentation/widgets/common/skeleton_list.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';

class TodayTransactionsScreen extends StatefulWidget {
  const TodayTransactionsScreen({super.key});

  @override
  State<TodayTransactionsScreen> createState() =>
      _TodayTransactionsScreenState();
}

class _TodayTransactionsScreenState extends State<TodayTransactionsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add listener for pagination
    _scrollController.addListener(_onScroll);

    // Fetch initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchInitialTransactions();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9) {
      context.read<TransactionProvider>().fetchMoreTransactions();
    }
  }

  void _navigateToCreateTransaction(BuildContext context) {
    Navigator.pushNamed(context, RouteConstants.createTransaction);
  }

  void _navigateToTransactionDetails(BuildContext context, String transactionId) {
    Navigator.pushNamed(
      context,
      RouteConstants.transactionDetails,
      arguments: transactionId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('معاملات اليوم'),
        actions: [
          Consumer<TransactionProvider>(
            builder: (context, provider, _) {
              return PopupMenuButton<String?>(
                icon: const Icon(Icons.filter_list),
                onSelected: (String? value) {
                  provider.setFilter(value);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                color: AppColors.surface(context),
                elevation: 4,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String?>>[
                  _buildFilterMenuItem(null, 'الكل', provider.filterType, icon: Icons.clear_all),
                  const PopupMenuDivider(),
                  _buildFilterMenuItem('send', 'إرسال', provider.filterType, icon: Icons.arrow_upward, color: AppColors.send),
                  _buildFilterMenuItem('receive', 'استقبال', provider.filterType, icon: Icons.arrow_downward, color: AppColors.receive),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              TransactionSummaryCard(
                totalTransactions: provider.summary['totalTransactions'] ?? 0,
                sendCount: provider.summary['sendCount'] ?? 0,
                receiveCount: provider.summary['receiveCount'] ?? 0,
                totalSendAmount: provider.summary['totalSendAmount'] ?? 0.0,
                totalReceiveAmount: provider.summary['totalReceiveAmount'] ?? 0.0,
                totalCommission: provider.summary['totalCommission'] ?? 0.0,
              ),
              Expanded(
                child: _buildContent(provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateTransaction(context),
        tooltip: 'معاملة جديدة',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add,),
      ),
    );
  }

  PopupMenuItem<String?> _buildFilterMenuItem(String? value, String text, String? groupValue, {IconData? icon, Color? color}) {
    return PopupMenuItem<String?>(
      value: value,
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: value == groupValue
                ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                : null,
          ),
          const SizedBox(width: 8),
          if (icon != null)
            Icon(icon, size: 18, color: color ?? AppColors.textSecondary(context)),
          if (icon != null)
            const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontWeight: value == groupValue ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(TransactionProvider provider) {
    if (provider.isLoading) {
      return const SkeletonList(itemCount: 5, itemHeight: 80);
    }

    if (provider.hasError) {
      return CustomErrorWidget(
        message: provider.errorMessage ?? 'حدث خطأ أثناء تحميل المعاملات.',
        onRetry: provider.fetchInitialTransactions,
      );
    }

    if (provider.transactions.isEmpty) {
      return EmptyStateWidget(
        message: provider.filterType == null ? 'لا توجد معاملات اليوم' : 'لا توجد معاملات بهذا الفلتر',
        description: 'ابدأ بإضافة معاملة جديدة',
        icon: Icons.receipt_long_outlined,
        actionText: 'معاملة جديدة',
        onAction: () => _navigateToCreateTransaction(context),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.fetchInitialTransactions,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80), // For FAB
        itemCount: provider.transactions.length + (provider.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.transactions.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final transaction = provider.transactions[index];
          return TransactionCard(
            transaction: transaction,
            onTap: () => _navigateToTransactionDetails(context, transaction.transactionId),
          );
        },
      ),
    );
  }
}