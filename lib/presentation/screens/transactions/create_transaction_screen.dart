import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:walletmanager/core/utils/error_translator.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/platform_settings_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../utils/wallet_extensions.dart';
import '../../../domain/usecases/transaction_fee_calculator.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/app_error_handler.dart';
import '../../../core/errors/error_severity.dart';
import '../../../core/di/service_locator.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_dropdown.dart';
import '../../widgets/wallet/wallet_limit_bar.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../core/enums/transaction_enums.dart';

class CreateTransactionScreen extends StatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerPhoneController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _commissionController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedWalletId;

  TransactionType? _transactionType; // ENUM refactor
  final PaymentStatus _paymentStatus = PaymentStatus.paid; // ENUM refactor

  bool _isTypeValidated = true;
  double _totalAmount = 0.0;
  double _serviceFee = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateTotal);
    _commissionController.addListener(_updateTotal);
    _customerPhoneController.addListener(_updateTotal);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider = context.read<WalletProvider>();
      if (walletProvider.wallets.isEmpty) {
        walletProvider.fetchInitialWallets();
      }

      // Pre-select wallet if ID is passed
      final arguments = ModalRoute.of(context)?.settings.arguments as String?;
      if (arguments != null) {
        setState(() {
          _selectedWalletId = arguments;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateTotal);
    _commissionController.removeListener(_updateTotal);
    _customerPhoneController.removeListener(_updateTotal);
    _customerPhoneController.dispose();
    _customerNameController.dispose();
    _amountController.dispose();
    _commissionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateTotal() {
    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final commission = double.tryParse(_commissionController.text) ?? 0.0;

      final wallet = _selectedWalletId != null
          ? context.read<WalletProvider>().walletMap[_selectedWalletId!]
          : null;

      final result = sl<TransactionFeeCalculator>().calculate(
        wallet: wallet,
        transactionType: _transactionType,
        amount: amount,
        commission: commission,
        receiverPhone: _customerPhoneController.text,
      );

      setState(() {
        _serviceFee = result.serviceFee;
        _totalAmount = result.totalAmount;
      });
    } on DomainException catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'calculate_total',
        severity: ErrorSeverity.low,
      );
      // Surface domain errors (like negative amount) via toast or similar
      if (kDebugMode) {
        debugPrint(
            '⚠️ [TX_CALC] Domain error during calculation: ${e.message}');
      }
      // We don't want to show a toast on every keystroke, but we should clear the total
      setState(() {
        _serviceFee = 0.0;
        _totalAmount = 0.0;
      });
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'calculate_total',
      );
      if (kDebugMode) {
        debugPrint('❌ [TX_CALC] Unexpected error during calculation: $e');
      }
    }
  }

  Future<void> _handleCreate() async {
    setState(() {
      _isTypeValidated = _transactionType != null;
    });

    if (!(_formKey.currentState?.validate() ?? false) || !_isTypeValidated) {
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final commission = double.tryParse(_commissionController.text) ?? 0.0;
    final transactionProvider = context.read<TransactionProvider>();

    try {
      final success = await transactionProvider.createTransaction(
        walletId: _selectedWalletId!,
        transactionType: _transactionType!,
        customerPhone: _customerPhoneController.text,
        customerName: _customerNameController.text,
        amount: amount,
        commission: commission,
        serviceFee: _serviceFee,
        paymentStatus: _paymentStatus,
        notes: _notesController.text,
      );

      if (mounted && success) {
        ToastUtils.showSuccess(
            AppLocalizations.of(context)!.transactionCreatedSuccess);
        Navigator.pop(context, true);
      } else if (mounted) {
        final error = transactionProvider.errorMessage != null
            ? ErrorTranslator.getLocalizedString(
                context, transactionProvider.errorMessage!)
            : AppLocalizations.of(context)!.transactionCreateFailed;
        _showErrorDialog(error);
      }
    } catch (e, stack) {
      AppErrorHandler.handle(
        e,
        stackTrace: stack,
        operation: 'create_transaction',
      );
      if (mounted) {
        final error = transactionProvider.errorMessage != null
            ? ErrorTranslator.getLocalizedString(
                context, transactionProvider.errorMessage!)
            : AppLocalizations.of(context)!.unexpectedError;
        _showErrorDialog(error);
      }
    } finally {
      if (mounted) {
        // Provider handles loading state
      }
    }
  }

  void _showErrorDialog(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.bottomSlide,
      title: AppLocalizations.of(context)!.errorTitle,
      desc: message,
      btnOkOnPress: () {},
      btnOkColor: Colors.red,
      btnOkText: AppLocalizations.of(context)!.okButton,
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.newTransactionTitle)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWalletSelection(l10n),
                const SizedBox(height: 16),
                if (_selectedWalletId != null) ...[
                  _buildTransactionTypeSection(l10n),
                  const SizedBox(height: 24),
                  _buildCustomerInfoSection(l10n),
                  const SizedBox(height: 24),
                  _buildAmountSection(l10n),
                  const SizedBox(height: 24),
                  _buildFeeSection(),
                  _buildLimitsPreview(l10n),
                  const SizedBox(height: 24),
                  _buildNotesSection(l10n),
                  const SizedBox(height: 32),
                  _buildCreateButton(l10n),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSelection(AppLocalizations l10n) {
    return Selector<
        WalletProvider,
        ({
          bool isLoading,
          List<WalletModel> wallets,
          Map<String, WalletModel> walletMap
        })>(
      selector: (_, provider) => (
        isLoading: provider.isLoading,
        wallets: provider.wallets,
        walletMap: provider.walletMap
      ),
      builder: (context, data, child) {
        if (data.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.wallets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(l10n.noWalletsAvailableMessage),
          );
        }

        return CustomDropdown<WalletModel>(
          value: _selectedWalletId != null
              ? data.walletMap[_selectedWalletId!]
              : null,
          hint: l10n.selectWalletHint,
          fillColor: AppColors.primary.withAlpha(13),

          // 1. تمرير قائمة المحافظ (Data) مباشرة
          itemsList: data.wallets,

          // 2. دالة استخراج النص المدمج (الاسم + رقم الهاتف المنسق)
          itemLabelBuilder: (WalletModel wallet) {
            String label =
                '${l10n.getWalletTypeName(wallet.walletType)} - ${NumberFormatter.formatPhoneNumber(wallet.phoneNumber)}';
            if (wallet.isFrozen) {
              label += ' ${l10n.walletIsFrozenShort}';
            }
            return label;
          },

          onChanged: (wallet) {
            if (wallet != null && wallet.isFrozen) {
              ToastUtils.showError(l10n.walletIsFrozen);
              setState(() {
                _selectedWalletId = null;
                _updateTotal();
              });
              return;
            }
            setState(() {
              _selectedWalletId = wallet?.walletId;
              _updateTotal(); // Recalculate fees when wallet changes
            });
          },
          validator: (value) {
            if (value == null) return l10n.pleaseSelectWallet;
            if (value.isFrozen) return l10n.walletIsFrozen;
            return null;
          },
        );
      },
    );
  }

  Widget _buildTransactionTypeSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.transactionType, style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TransactionTypeButton(
                label: l10n.send,
                icon: Icons.arrow_upward,
                color: AppColors.send,
                isSelected:
                    _transactionType == TransactionType.debit, // ENUM refactor
                onTap: () {
                  setState(() => _transactionType = TransactionType.debit);
                  _updateTotal();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TransactionTypeButton(
                label: l10n.receive,
                icon: Icons.arrow_downward,
                color: AppColors.receive,
                isSelected:
                    _transactionType == TransactionType.credit, // ENUM refactor
                onTap: () {
                  setState(() => _transactionType = TransactionType.credit);
                  _updateTotal();
                },
              ),
            ),
          ],
        ),
        if (!_isTypeValidated)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 8.0, end: 12),
            child: Text(
              l10n.pleaseSelectTransactionType,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerInfoSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.clientData, style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        CustomTextField(
          controller: _customerPhoneController,
          labelText: l10n.clientPhoneNumber,
          hintText: l10n.phonePlaceholder,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          validator: Validators.validatePhoneNumber,
          prefixIcon: const Icon(Icons.phone),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _customerNameController,
          labelText: l10n.clientNameOptional,
          hintText: l10n.enterClientName,
          keyboardType: TextInputType.name,
          prefixIcon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Widget _buildAmountSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.amountAndCommission, style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomTextField(
                controller: _amountController,
                labelText: l10n.amountLabel,
                hintText: l10n.amountPlaceholder,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) =>
                    Validators.validateAmount(val, minAmount: 0),
                prefixIcon: const Icon(Icons.money),
                onChanged: (_) => _updateTotal(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                controller: _commissionController,
                labelText: l10n.commissionLabel,
                hintText: l10n.amountPlaceholder,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val != null &&
                      val.isNotEmpty &&
                      (double.tryParse(val) ?? -1) < 0) {
                    return l10n.invalidValue;
                  }
                  return null;
                },
                prefixIcon: const Icon(Icons.attach_money),
                onChanged: (_) => _updateTotal(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(13),
            borderRadius: BorderRadius.circular(8),
            border: null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.totalLabel, style: AppTextStyles.labelMedium),
              Text(
                NumberFormatter.formatAmount(_totalAmount),
                style: AppTextStyles.h3.copyWith(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeSection() {
    if (_transactionType != TransactionType.debit || _serviceFee <= 0) {
      // ENUM refactor
      return const SizedBox.shrink();
    }

    final localizations = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final totalDeduction = amount + _serviceFee;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.transactionFees,
                style: AppTextStyles.bodyMedium,
              ),
              Text(
                NumberFormatter.formatAmount(_serviceFee, showCurrency: true),
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations.totalDeduction,
                style: AppTextStyles.bodyLarge
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                NumberFormatter.formatAmount(totalDeduction,
                    showCurrency: true),
                style: AppTextStyles.h3.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsPreview(AppLocalizations l10n) {
    if (_selectedWalletId == null || _transactionType == null) {
      return const SizedBox.shrink();
    }

    return Selector<WalletProvider, WalletModel?>(
      selector: (context, provider) => provider.walletMap[_selectedWalletId!],
      builder: (context, wallet, child) {
        if (wallet == null) return const SizedBox.shrink();

        final amount = double.tryParse(_amountController.text) ?? 0.0;
        final isSend =
            _transactionType == TransactionType.debit; // ENUM refactor
        final limits = isSend ? wallet.getLimits() : wallet.getReceiveLimits();

        // Fetch dynamic limits matching the wallet's current type and status
        final settings = context.read<PlatformSettingsProvider>().settings;
        final dynamicLimits = wallet.getDynamicNetworkLimits(settings);

        final dailyLimit = isSend ? dynamicLimits.dailySend : dynamicLimits.dailyReceive;
        final monthlyLimit = isSend ? dynamicLimits.monthlySend : dynamicLimits.monthlyReceive;

        final newUsed = limits.dailyUsed + amount;
        final newMonthlyUsed = limits.monthlyUsed + amount;

        // Check individual limits
        final bool dailyExceeded = newUsed > dailyLimit;
        final bool monthlyExceeded = newMonthlyUsed > monthlyLimit;
        final bool willExceed = dailyExceeded || monthlyExceeded;

        final double dailyPercentage = dailyLimit > 0 ? (newUsed / dailyLimit) * 100 : 0.0;
        final double monthlyPercentage = monthlyLimit > 0 ? (newMonthlyUsed / monthlyLimit) * 100 : 0.0;

        final dailyWarningLevel = dailyExceeded
            ? 'red'
            : (dailyPercentage >= 70 ? 'yellow' : 'green');
        final monthlyWarningLevel = monthlyExceeded
            ? 'red'
            : (monthlyPercentage >= 70 ? 'yellow' : 'green');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: willExceed
                ? AppColors.error.withAlpha(13)
                : AppColors.info.withAlpha(13),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: willExceed
                  ? AppColors.error.withAlpha(51)
                  : AppColors.info.withAlpha(51),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    willExceed
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: willExceed ? AppColors.error : AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.reviewWalletLimits,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: willExceed ? AppColors.error : AppColors.info,
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              WalletLimitBar(
                label: l10n.dailyLimitAfterTransaction,
                used: newUsed,
                limit: dailyLimit,
                percentage: dailyPercentage,
                warningLevel: dailyWarningLevel,
              ),
              const SizedBox(height: 16),
              WalletLimitBar(
                label: l10n.monthlyLimitAfterTransaction,
                used: newMonthlyUsed,
                limit: monthlyLimit,
                percentage: monthlyPercentage,
                warningLevel: monthlyWarningLevel,
              ),
              if (willExceed)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Text(
                    l10n.walletLimitWarning,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotesSection(AppLocalizations l10n) {
    return CustomTextField(
      controller: _notesController,
      labelText: l10n.notesOptional,
      hintText: l10n.additionalTransactionDetails,
      maxLines: 3,
      maxLength: 200,
      validator: (value) => Validators.validateNotes(value, maxLength: 200),
      prefixIcon: const Icon(Icons.note_alt_outlined),
    );
  }

  Widget _buildCreateButton(AppLocalizations l10n) {
    return Selector<TransactionProvider,
        ({bool isCreating, String? errorMessage, bool hasError})>(
      selector: (_, provider) => (
        isCreating: provider.isCreating,
        errorMessage: provider.errorMessage,
        hasError: provider.hasError
      ),
      builder: (context, data, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.hasError && data.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data.errorMessage!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            CustomButton(
              text: l10n.createTransactionButton,
              onPressed: _handleCreate,
              isLoading: data.isCreating,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        );
      },
    );
  }
}

class _TransactionTypeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TransactionTypeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(26) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.divider(context),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
