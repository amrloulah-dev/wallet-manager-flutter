import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../data/models/transaction_model.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import '../../../providers/employee_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';

class TransactionDetailsScreen extends StatefulWidget {
  const TransactionDetailsScreen({super.key});

  @override
  State<TransactionDetailsScreen> createState() =>
      _TransactionDetailsScreenState();
}

class _TransactionDetailsScreenState extends State<TransactionDetailsScreen> {
  String? _transactionId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final transactionId =
          ModalRoute.of(context)?.settings.arguments as String?;
      if (transactionId != null) {
        _loadTransactionDetails(transactionId);
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _loadTransactionDetails(String transactionId) async {
    setState(() {
      _transactionId = transactionId;
      _isLoading = true;
    });
    await context.read<TransactionProvider>().selectTransaction(transactionId);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المعاملة'),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (_isLoading) {
            return LoadingIndicator(message: 'جاري تحميل التفاصيل...');
          }
          if (provider.selectedTransaction == null) {
            return CustomErrorWidget(
              message: provider.errorMessage ?? 'لم يتم العثور على المعاملة',
              onRetry: () {
                if (_transactionId != null) {
                  _loadTransactionDetails(_transactionId!);
                }
              },
            );
          }
          return _buildTransactionDetails(context, provider.selectedTransaction!);
        },
      ),
    );
  }

  Widget _buildTransactionDetails(BuildContext context, TransactionModel transaction) {
    return Hero(
      tag: 'transaction_${transaction.transactionId}',
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTransactionTypeCard(transaction),
              const SizedBox(height: 16),
              _buildAmountCard(context, transaction),
              const SizedBox(height: 16),
              _buildCustomerInfoCard(context, transaction),
              const SizedBox(height: 16),
              _buildWalletInfoCard(context, transaction),
              const SizedBox(height: 16),
              _buildDateTimeCard(context, transaction),
              if (transaction.isDebt) ...[
                const SizedBox(height: 16),
                _buildPaymentStatusCard(transaction),
              ],
              if (transaction.notes != null && transaction.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(context, transaction),
              ],
              const SizedBox(height: 16),
              _buildMetadataCard(context, transaction),
            ],
          ),
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
              Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(context))),
              const SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ??
                    AppTextStyles.bodyLarge
                        .copyWith(fontWeight: FontWeight.bold, color: valueColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Card _buildBaseCard({required Widget child}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildTransactionTypeCard(TransactionModel transaction) {
    return _buildBaseCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: transaction.transactionTypeColor.withAlpha((0.1 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.transactionTypeIcon,
              color: transaction.transactionTypeColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نوع المعاملة', style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Text(
                  transaction.transactionTypeDisplay,
                  style: AppTextStyles.h3.copyWith(
                    color: transaction.transactionTypeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context, TransactionModel transaction) {
    return _buildBaseCard(
      child: Column(
        children: [
          _buildInfoRow(
            context: context,
            icon: Icons.money,
            label: 'المبلغ',
            value: NumberFormatter.formatAmount(transaction.amount),
            valueStyle: AppTextStyles.h2.copyWith(
              color: transaction.transactionTypeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.add_circle_outline,
            label: 'العمولة',
            value: NumberFormatter.formatAmount(transaction.commission),
            valueColor: AppColors.success,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.functions,
            label: 'الإجمالي',
            value: NumberFormatter.formatAmount(transaction.totalAmount),
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(BuildContext context, TransactionModel transaction) {
    if (transaction.customerPhone == null || transaction.customerPhone!.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بيانات العميل', style: AppTextStyles.h3),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.phone_android,
            label: 'رقم الموبايل',
            value: NumberFormatter.formatPhoneNumber(transaction.customerPhone),
          ),
          if (transaction.customerName != null &&
              transaction.customerName!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.person,
              label: 'الاسم',
              value: transaction.customerName!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletInfoCard(BuildContext context, TransactionModel transaction) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final WalletModel? wallet = walletProvider.wallets.firstWhereOrNull((w) => w.walletId == transaction.walletId);

        return _buildBaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('المحفظة المستخدمة', style: AppTextStyles.h3),
              const Divider(height: 24),
              if (wallet == null)
                const Text('لا يمكن العثور على تفاصيل المحفظة.')
              else ...[
                _buildInfoRow(
                  context: context,
                  icon: Icons.account_balance_wallet,
                  label: 'رقم المحفظة',
                  value: NumberFormatter.formatPhoneNumber(wallet.phoneNumber),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context: context,
                  icon: wallet.walletTypeIcon,
                  label: 'نوع المحفظة',
                  value: wallet.walletTypeDisplayName,
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateTimeCard(BuildContext context, TransactionModel transaction) {
    return _buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الوقت والتاريخ', style: AppTextStyles.h3),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.calendar_today,
            label: 'التاريخ',
            value: transaction.formattedDate,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context: context,
            icon: Icons.access_time,
            label: 'الوقت',
            value: transaction.formattedTime,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context: context,
            icon: Icons.history,
            label: 'منذ',
            value: transaction.relativeTime,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusCard(TransactionModel transaction) {
    return _buildBaseCard(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha((0.1 * 255).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'هذه المعاملة دين',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.warning),
                  ),
                  const SizedBox(height: 4),
                  const Text('لم يتم دفع المبلغ من قبل العميل وقت إنشاء المعاملة.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, TransactionModel transaction) {
    return _buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الملاحظات', style: AppTextStyles.h3),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.note_alt_outlined,
            label: 'الملاحظات المسجلة',
            value: transaction.notes!,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context, TransactionModel transaction) {
    final authProvider = context.watch<AuthProvider>();
    final employeeProvider = context.watch<EmployeeProvider>();

    final creatorId = transaction.createdBy;
    String creatorName = 'غير معروف';

    // Find the creator's name
    final employee = employeeProvider.getEmployeeById(creatorId);
    if (employee != null) {
      creatorName = employee.fullName;
    } else if (creatorId == authProvider.currentStore?.ownerId) {
      creatorName = authProvider.currentStore?.ownerName ?? 'المالك';
    }


    return _buildBaseCard(
      child: Column(
        children: [
          _buildInfoRow(
            context: context,
            icon: Icons.fingerprint,
            label: 'معرف المعاملة',
            value: transaction.transactionId,
            valueStyle: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context: context,
            icon: Icons.person_add_alt_1,
            label: 'تم إنشاؤها بواسطة',
            value: creatorName,
            valueStyle: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
