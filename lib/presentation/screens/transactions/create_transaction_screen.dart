import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_dropdown.dart';
import '../../widgets/wallet/wallet_limit_bar.dart';
import '../../../core/utils/fee_calculator.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

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

  WalletModel? _selectedWallet;
  String? _preSelectedWalletId;

  String? _transactionType; // 'send' | 'receive'
  String _paymentStatus = 'paid'; // 'paid' | 'debt'

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
      // Pre-select wallet if ID is passed
      final arguments = ModalRoute.of(context)?.settings.arguments as String?;
      if (arguments != null) {
        _preSelectedWalletId = arguments;
        final walletProvider = context.read<WalletProvider>();
        if (walletProvider.wallets.isNotEmpty) {
          _trySelectWallet(walletProvider.wallets);
        }
      }
    });
  }

  void _trySelectWallet(List<WalletModel> wallets) {
    if (_preSelectedWalletId != null) {
      try {
        final walletToSelect =
            wallets.firstWhere((w) => w.walletId == _preSelectedWalletId);
        setState(() {
          _selectedWallet = walletToSelect;
        });
      } catch (e) {
        // Wallet not found in the list
      }
    }
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
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final commission = double.tryParse(_commissionController.text) ?? 0.0;

    double fee = 0.0;
    if (_selectedWallet != null && _transactionType == 'send') {
      fee = FeeCalculator.calculateTransactionFee(
        amount: amount,
        sourceWalletType: _selectedWallet!.walletType,
        receiverPhone: _customerPhoneController.text,
      );
    }

    setState(() {
      _serviceFee = fee;
      _totalAmount = amount + commission;
    });
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
    final authProvider = context.read<AuthProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null) {
      ToastUtils.showError('خطأ في المصادقة، يرجى تسجيل الدخول مرة أخرى');
      return;
    }

    final success = await transactionProvider.createTransaction(
      walletId: _selectedWallet!.walletId,
      transactionType: _transactionType!,
      customerPhone: _customerPhoneController.text,
      customerName: _customerNameController.text,
      amount: amount,
      commission: commission,
      serviceFee: _serviceFee,
      paymentStatus: _paymentStatus,
      notes: _notesController.text,
      createdBy: currentUserId,
    );

    if (mounted && success) {
      ToastUtils.showSuccess('تم إنشاء المعاملة بنجاح');
      Navigator.pop(context, true);
    } else if (mounted) {
      ToastUtils.showError(
          transactionProvider.errorMessage ?? 'فشل إنشاء المعاملة');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('معاملة جديدة')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWalletSelection(),
                const SizedBox(height: 16),
                if (_selectedWallet != null) ...[
                  _buildTransactionTypeSection(),
                  const SizedBox(height: 24),
                  _buildCustomerInfoSection(),
                  const SizedBox(height: 24),
                  _buildAmountSection(),
                  const SizedBox(height: 24),
                  _buildFeeSection(),
                  _buildLimitsPreview(),
                  const SizedBox(height: 24),
                  _buildNotesSection(),
                  const SizedBox(height: 32),
                  _buildCreateButton(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSelection() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (walletProvider.wallets.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('لا توجد محافظ متاحة. يرجى إضافة محفظة أولاً.'),
          );
        }

        // Try to pre-select wallet if not already selected
        if (_selectedWallet == null) {
          _trySelectWallet(walletProvider.wallets);
        }

        return CustomDropdown<WalletModel>(
          value: _selectedWallet,
          hint: 'اختر المحفظة لإجراء المعاملة',
          items: walletProvider.wallets.map((WalletModel wallet) {
            return DropdownMenuItem<WalletModel>(
              value: wallet,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withAlpha((0.3 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${wallet.walletTypeDisplayName} - ${NumberFormatter.formatPhoneNumber(wallet.phoneNumber)}',
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          selectedItemBuilder: (BuildContext context) {
            return walletProvider.wallets.map((WalletModel wallet) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${wallet.walletTypeDisplayName} - ${NumberFormatter.formatPhoneNumber(wallet.phoneNumber)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              );
            }).toList();
          },
          onChanged: (wallet) {
            setState(() {
              _selectedWallet = wallet;
              _preSelectedWalletId =
                  null; // Clear pre-selection after manual choice
              _updateTotal(); // Recalculate fees when wallet changes
            });
          },
          validator: (value) => value == null ? 'يرجى اختيار محفظة' : null,
          fillColor: AppColors.primary.withAlpha((0.05 * 255).round()),
        );
      },
    );
  }

  Widget _buildTransactionTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نوع المعاملة', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TransactionTypeButton(
                label: 'إرسال',
                icon: Icons.arrow_upward,
                color: AppColors.send,
                isSelected: _transactionType == 'send',
                onTap: () {
                  setState(() => _transactionType = 'send');
                  _updateTotal();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TransactionTypeButton(
                label: 'استقبال',
                icon: Icons.arrow_downward,
                color: AppColors.receive,
                isSelected: _transactionType == 'receive',
                onTap: () {
                  setState(() => _transactionType = 'receive');
                  _updateTotal();
                },
              ),
            ),
          ],
        ),
        if (!_isTypeValidated)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, right: 12),
            child: Text(
              'يرجى اختيار نوع المعاملة',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomerInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('بيانات العميل', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        CustomTextField(
          controller: _customerPhoneController,
          labelText: 'رقم موبايل العميل',
          hintText: '01xxxxxxxxx',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          validator: Validators.validatePhoneNumber,
          prefixIcon: const Icon(Icons.phone),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _customerNameController,
          labelText: 'اسم العميل (اختياري)',
          hintText: 'أدخل اسم العميل',
          keyboardType: TextInputType.name,
          prefixIcon: const Icon(Icons.person_outline),
        ),
      ],
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المبلغ والعمولة', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CustomTextField(
                controller: _amountController,
                labelText: 'المبلغ',
                hintText: '0.00',
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
                labelText: 'العمولة',
                hintText: '0.00',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val != null &&
                      val.isNotEmpty &&
                      (double.tryParse(val) ?? -1) < 0) {
                    return 'قيمة غير صالحة';
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
            color: AppColors.primary.withAlpha((0.05 * 255).round()),
            borderRadius: BorderRadius.circular(8),
            border: null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الإجمالي', style: AppTextStyles.labelMedium),
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
    if (_transactionType != 'send' || _serviceFee <= 0)
      return const SizedBox.shrink();

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
                '${NumberFormatter.formatAmount(_serviceFee)} EGP',
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
                '${NumberFormatter.formatAmount(totalDeduction)} EGP',
                style: AppTextStyles.h3.copyWith(color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsPreview() {
    if (_selectedWallet == null || _transactionType == null) {
      return const SizedBox.shrink();
    }

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final isSend = _transactionType == 'send';
    final limits = isSend
        ? _selectedWallet!.getLimits()
        : _selectedWallet!.getReceiveLimits();
    final newUsed = limits.dailyUsed + amount;
    final newMonthlyUsed = limits.monthlyUsed + amount;

    // Check individual limits
    final bool dailyExceeded = newUsed > limits.dailyLimit;
    final bool monthlyExceeded = newMonthlyUsed > limits.monthlyLimit;
    final bool willExceed = dailyExceeded || monthlyExceeded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: willExceed
            ? AppColors.error.withAlpha((0.05 * 255).round())
            : AppColors.info.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: willExceed
              ? AppColors.error.withAlpha((0.2 * 255).round())
              : AppColors.info.withAlpha((0.2 * 255).round()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                willExceed ? Icons.warning_amber_rounded : Icons.info_outline,
                color: willExceed ? AppColors.error : AppColors.info,
              ),
              const SizedBox(width: 8),
              Text(
                'مراجعة حدود المحفظة',
                style: AppTextStyles.labelMedium.copyWith(
                  color: willExceed ? AppColors.error : AppColors.info,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          WalletLimitBar(
            label: 'الحد اليومي (بعد المعاملة)',
            used: newUsed,
            limit: limits.dailyLimit,
            percentage:
                limits.dailyLimit > 0 ? (newUsed / limits.dailyLimit) * 100 : 0,
            warningLevel: dailyExceeded ? 'red' : 'green',
          ),
          const SizedBox(height: 16),
          WalletLimitBar(
            label: 'الحد الشهري (بعد المعاملة)',
            used: newMonthlyUsed,
            limit: limits.monthlyLimit,
            percentage: limits.monthlyLimit > 0
                ? (newMonthlyUsed / limits.monthlyLimit) * 100
                : 0,
            warningLevel: monthlyExceeded ? 'red' : 'green',
          ),
          if (willExceed)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Text(
                'تحذير: هذه المعاملة ستتجاوز الحد المسموح به للمحفظة.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return CustomTextField(
      controller: _notesController,
      labelText: 'ملاحظات (اختياري)',
      hintText: 'أي تفاصيل إضافية عن المعاملة',
      maxLines: 3,
      maxLength: 200,
      validator: (value) => Validators.validateNotes(value, maxLength: 200),
      prefixIcon: const Icon(Icons.note_alt_outlined),
    );
  }

  Widget _buildCreateButton() {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (provider.hasError && provider.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            CustomButton(
              text: 'إنشاء المعاملة',
              onPressed: _handleCreate,
              isLoading: provider.isCreating,
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
          color: isSelected
              ? color.withAlpha((0.1 * 255).round())
              : AppColors.surface(context),
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
