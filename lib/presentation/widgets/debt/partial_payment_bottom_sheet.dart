import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/data/models/debt_model.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/providers/debt_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/number_formatter.dart';
import '../common/custom_button.dart';
import '../common/custom_text_field.dart';

class PartialPaymentBottomSheet extends StatefulWidget {
  final DebtModel debt;

  const PartialPaymentBottomSheet({super.key, required this.debt});

  @override
  State<PartialPaymentBottomSheet> createState() =>
      _PartialPaymentBottomSheetState();
}

class _PartialPaymentBottomSheetState extends State<PartialPaymentBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final ValueNotifier<double> _newAmountNotifier = ValueNotifier(0);
  bool _isPaymentMode = true; // true for Payment, false for Addition

  @override
  void initState() {
    super.initState();
    _newAmountNotifier.value = widget.debt.amountDue;
    _amountController.addListener(_updateNewAmount);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateNewAmount);
    _amountController.dispose();
    _newAmountNotifier.dispose();
    super.dispose();
  }

  void _updateNewAmount() {
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    setState(() {
      if (_isPaymentMode) {
        _newAmountNotifier.value = widget.debt.amountDue - enteredAmount;
      } else {
        _newAmountNotifier.value = widget.debt.amountDue + enteredAmount;
      }
    });
  }

  Future<void> _handleSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;
    final debtProvider = context.read<DebtProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUserId;

    if (currentUserId == null) {
      ToastUtils.showError('خطأ: المستخدم غير مسجل');
      return;
    }

    bool success;
    if (_isPaymentMode) {
      // This handles both partial and full payments.
      // The repository logic will mark the debt as 'paid' if the amount is fully paid.
      success = await debtProvider.payPartialDebt(
        widget.debt.debtId,
        enteredAmount,
        currentUserId,
      );
    } else {
      // --- FIX APPLIED ---
      // Use the correct transactional method 'addPartialDebt'.
      // This method ensures that both the debt document and the summary stats are updated atomically.
      // It handles all cases, including:
      // 1. Adding amount to an already open debt.
      // 2. Re-opening a paid debt by adding a new amount.
      success = await debtProvider.addPartialDebt(
        widget.debt.debtId,
        enteredAmount,
        currentUserId,
      );
    }

    if (mounted) {
      if (success) {
        ToastUtils.showSuccess('تم تحديث الدين بنجاح');
        Navigator.pop(context);
      } else {
        ToastUtils.showError(
            debtProvider.errorMessage ?? 'فشل تحديث الدين');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildModeToggle(),
            const SizedBox(height: 24),
            _buildAmountInfo(),
            const SizedBox(height: 16),
            _buildPaymentField(),
            const SizedBox(height: 16),
            _buildRemainingBalance(),
            const SizedBox(height: 24),
            _buildSaveButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.divider(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'تعديل الدين',
          style: AppTextStyles.h3,
        ),
        const SizedBox(height: 8),
        Text(
          widget.debt.customerName,
          style: AppTextStyles.bodyLarge,
        ),
        Text(
          NumberFormatter.formatPhoneNumber(widget.debt.customerPhone),
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary(context)),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Center(
      child: ToggleButtons(
        isSelected: [_isPaymentMode, !_isPaymentMode],
        onPressed: (index) {
          setState(() {
            _isPaymentMode = index == 0;
            _updateNewAmount();
            _formKey.currentState?.reset();
          });
        },
        borderRadius: BorderRadius.circular(8.0),
        selectedColor: Colors.white,
        fillColor: _isPaymentMode ? AppColors.success : AppColors.error,
        color: _isPaymentMode ? AppColors.success : AppColors.error,
        borderColor: AppColors.divider(context),
        selectedBorderColor: _isPaymentMode ? AppColors.success : AppColors.error,
        children: const <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.arrow_downward),
                SizedBox(width: 8),
                Text('دفعة'),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Icon(Icons.arrow_upward),
                SizedBox(width: 8),
                Text('إضافة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha((0.05 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('المبلغ الحالي', style: AppTextStyles.labelLarge),
          Text(
            NumberFormatter.formatAmount(widget.debt.amountDue),
            style: AppTextStyles.h2.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentField() {
    return CustomTextField(
      controller: _amountController,
      labelText: 'المبلغ',
      hintText: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      prefixIcon: const Icon(Icons.attach_money),
      autofocus: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى إدخال المبلغ';
        }
        final amount = double.tryParse(value);
        if (amount == null) {
          return 'مبلغ غير صحيح';
        }
        if (amount <= 0) {
          return 'المبلغ يجب أن يكون أكبر من صفر';
        }
        if (_isPaymentMode && amount > widget.debt.amountDue) {
          return 'المبلغ المدفوع أكبر من الدين';
        }
        return null;
      },
    );
  }

  Widget _buildRemainingBalance() {
    return ValueListenableBuilder<double>(
      valueListenable: _newAmountNotifier,
      builder: (context, newAmount, child) {
        if (_amountController.text.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المبلغ الجديد:', style: AppTextStyles.bodyMedium),
              Text(
                NumberFormatter.formatAmount(newAmount),
                style: AppTextStyles.labelLarge.copyWith(color: AppColors.info),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Consumer<DebtProvider>(
      builder: (context, provider, child) {
        return CustomButton(
          text: 'حفظ التعديل',
          onPressed: _handleSave,
          isLoading: provider.isUpdating,
        );
      },
    );
  }
}