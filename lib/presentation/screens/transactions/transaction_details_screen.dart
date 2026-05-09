import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../data/models/transaction_model.dart';
import '../../utils/model_ui_extensions.dart';
import '../../../data/models/wallet_model.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/error_widget.dart';
import '../../../l10n/arb/app_localizations.dart';
import '../../utils/wallet_extensions.dart';
import '../../../core/enums/wallet_enums.dart';

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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactionDetails),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (_isLoading) {
            return LoadingIndicator(message: l10n.loadingDetails);
          }
          if (provider.hasError || provider.selectedTransaction == null) {
            return CustomErrorWidget(
              message: provider.errorMessage ?? l10n.transactionNotFound,
              onRetry: () {
                if (_transactionId != null) {
                  _loadTransactionDetails(_transactionId!);
                }
              },
            );
          }
          return _buildTransactionDetails(
              context, provider.selectedTransaction!);
        },
      ),
    );
  }

  Widget _buildTransactionDetails(
      BuildContext context, TransactionModel transaction) {
    return Hero(
      tag: 'transaction_${transaction.transactionId}',
      child: Material(
        type: MaterialType.transparency,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTransactionTypeCard(context, transaction),
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
                _buildPaymentStatusCard(context, transaction),
              ],
              if (transaction.notes != null &&
                  transaction.notes!.isNotEmpty) ...[
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
              Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary(context))),
              const SizedBox(height: 4),
              Text(
                value,
                style: valueStyle ??
                    AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold, color: valueColor),
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

  Widget _buildTransactionTypeCard(
      BuildContext context, TransactionModel transaction) {
    final l10n = AppLocalizations.of(context)!;
    return _buildBaseCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: transaction.transactionTypeColor.withAlpha(26),
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
                Text(l10n.transactionType, style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Text(
                  transaction.getTransactionTypeDisplay(l10n),
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
    final l10n = AppLocalizations.of(context)!;
    return _buildBaseCard(
      child: Column(
        children: [
          _buildInfoRow(
            context: context,
            icon: Icons.money,
            label: l10n.amount,
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
            label: l10n.commission,
            value: NumberFormatter.formatAmount(transaction.commission),
            valueColor: AppColors.success,
          ),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.functions,
            label: l10n.total,
            value: NumberFormatter.formatAmount(transaction.totalAmount),
            valueColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard(
      BuildContext context, TransactionModel transaction) {
    if (transaction.customerPhone == null ||
        transaction.customerPhone!.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return _buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.customerDetails, style: AppTextStyles.h3),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.phone_android,
            label: l10n.phoneNumber,
            value: NumberFormatter.formatPhoneNumber(transaction.customerPhone),
          ),
          if (transaction.customerName != null &&
              transaction.customerName!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildInfoRow(
              context: context,
              icon: Icons.person,
              label: l10n.name,
              value: transaction.customerName!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWalletInfoCard(
      BuildContext context, TransactionModel transaction) {
    final l10n = AppLocalizations.of(context)!;
    return Selector<WalletProvider, WalletModel?>(
      selector: (context, provider) => provider.walletMap[transaction.walletId],
      builder: (context, wallet, child) {
        return _buildBaseCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.usedWallet, style: AppTextStyles.h3),
              const Divider(height: 24),
              if (wallet == null)
                Text(l10n.walletNotFoundDetails)
              else ...[
                _buildInfoRow(
                  context: context,
                  icon: Icons.account_balance_wallet,
                  label: l10n.walletNumber,
                  value: NumberFormatter.formatPhoneNumber(wallet.phoneNumber),
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  context: context,
                  icon: wallet.walletTypeIcon,
                  label: l10n.walletType,
                  value: wallet.walletType == WalletType.vodafoneCash
                      ? l10n.vodafoneCash
                      : (wallet.walletType == WalletType.instaPay
                          ? l10n.instapay
                          : wallet.walletType.name), // ENUM refactor
                ),
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateTimeCard(
      BuildContext context, TransactionModel transaction) {
    final l10n = AppLocalizations.of(context)!;
    return _buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.timeAndDate, style: AppTextStyles.h3),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.calendar_today,
            label: l10n.date,
            value: transaction.formattedDate,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context: context,
            icon: Icons.access_time,
            label: l10n.time,
            value: transaction.formattedTime,
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context: context,
            icon: Icons.history,
            label: l10n.since,
            value: transaction.getRelativeTime(l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentStatusCard(
      BuildContext context, TransactionModel transaction) {
    final l10n = AppLocalizations.of(context)!;
    return _buildBaseCard(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.transactionIsDebt,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.warning),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.debtWarningMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, TransactionModel transaction) {
    final l10n = AppLocalizations.of(context)!;
    return _buildBaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.notes, style: AppTextStyles.h3),
          const Divider(height: 24),
          _buildInfoRow(
            context: context,
            icon: Icons.note_alt_outlined,
            label: l10n.recordedNotes,
            value: transaction.notes!,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(
      BuildContext context, TransactionModel transaction) {
    final l10n = AppLocalizations.of(context)!;
    // 1. Resolve Creator Name
    final creatorName = transaction.createdByName ?? l10n.unknown;

    // 2. Resolve Creator Role & Styles
    String roleDisplay = '';
    IconData creatorIcon = Icons.person_outline;
    Color? roleColor;

    final role = UserRole.fromString(transaction.creatorRole ?? '');
    if (role == UserRole.owner) {
      roleDisplay = l10n.ownerRoleSuffix;
      creatorIcon = Icons.admin_panel_settings_outlined;
      roleColor = AppColors.primary;
    } else if (role == UserRole.employee) {
      roleDisplay = l10n.employeeRoleSuffix;
      creatorIcon = Icons.person_outline;
    }

    // Combine
    final fullCreatorDisplay = '$creatorName$roleDisplay';

    return _buildBaseCard(
      child: Column(
        children: [
          _buildInfoRow(
            context: context,
            icon: Icons.fingerprint,
            label: l10n.transactionIdLabel,
            value: transaction.transactionId,
            valueStyle: AppTextStyles.caption.copyWith(letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context: context,
            icon: creatorIcon,
            label: l10n.createdBy,
            value: fullCreatorDisplay,
            valueColor: roleColor, // Apply specific color if set
            valueStyle: AppTextStyles.bodyMedium
                .copyWith(fontWeight: FontWeight.bold, color: roleColor),
          ),
        ],
      ),
    );
  }
}
