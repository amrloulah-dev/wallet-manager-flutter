import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/debt_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class AddDebtScreen extends StatefulWidget {
  final String? initialDebtType;
  const AddDebtScreen({super.key, this.initialDebtType});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _debtType = 'transaction'; // 'transaction' | 'store_sale'

  @override
  void initState() {
    super.initState();
    if (widget.initialDebtType != null) {
      _debtType = widget.initialDebtType!;
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final debtProvider = context.read<DebtProvider>();
    final authProvider = context.read<AuthProvider>();

    debtProvider.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final currentUserId = authProvider.currentUserId;
    if (currentUserId == null) {
      ToastUtils.showError('خطأ في المصادقة، يرجى تسجيل الدخول مرة أخرى');
      return;
    }

    final success = await debtProvider.createDebt(
      customerName: _customerNameController.text,
      customerPhone: _customerPhoneController.text,
      debtType: _debtType,
      amountDue: double.parse(_amountController.text),
      notes: _notesController.text,
      createdBy: currentUserId,
    );

    if (success && mounted) {
      ToastUtils.showSuccess('تم إضافة الدين بنجاح');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إضافة دين جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCustomerInfoSection(),
                const SizedBox(height: 24),
                _buildDebtTypeSection(),
                const SizedBox(height: 24),
                _buildAmountSection(),
                const SizedBox(height: 24),
                _buildNotesSection(),
                const SizedBox(height: 32),
                _buildCreateButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('بيانات العميل', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _customerNameController,
          labelText: 'اسم العميل',
          hintText: 'أدخل اسم العميل بالكامل',
          validator: (val) => Validators.validateRequired(val, 'اسم العميل'),
          prefixIcon: const Icon(Icons.person_outline),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _customerPhoneController,
          labelText: 'رقم موبايل العميل',
          hintText: '01xxxxxxxxx',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          validator: Validators.validatePhoneNumber,
          prefixIcon: const Icon(Icons.phone_outlined),
        ),
      ],
    );
  }

  Widget _buildDebtTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نوع الدين', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        _buildDebtTypeTile(
          title: 'معاملة محفظة',
          subtitle: 'دين ناتج عن معاملة إرسال لم يتم دفعها',
          value: 'transaction',
          icon: Icons.swap_horiz,
        ),
        const SizedBox(height: 8),
        _buildDebtTypeTile(
          title: 'بيع من المحل',
          subtitle: 'دين ناتج عن عملية بيع آجلة من المحل',
          value: 'store_sale',
          icon: Icons.storefront_outlined,
        ),
      ],
    );
  }

  Widget _buildDebtTypeTile({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _debtType == value;
    return Card(
      elevation: 0,
      color: isSelected
          ? AppColors.primary.withAlpha((0.05 * 255).round())
          : AppColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.divider(context),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _debtType,
        onChanged: (val) => setState(() => _debtType = val!),
        title: Text(title, style: AppTextStyles.labelLarge),
        subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
        secondary: Icon(icon, color: AppColors.primary),
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('المبلغ المستحق', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _amountController,
          labelText: 'المبلغ',
          hintText: '0.00',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (val) => Validators.validateAmount(val, minAmount: 1),
          prefixIcon: const Icon(Icons.attach_money_outlined),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'سيتم إضافة هذا الدين إلى قائمة الديون المفتوحة.',
                  style:
                      AppTextStyles.bodySmall.copyWith(color: AppColors.info),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection() {
    return CustomTextField(
      controller: _notesController,
      labelText: 'ملاحظات (اختياري)',
      hintText: 'أي تفاصيل إضافية عن الدين',
      maxLines: 3,
      maxLength: 200,
      validator: (value) => Validators.validateNotes(value, maxLength: 200),
      prefixIcon: const Icon(Icons.note_alt_outlined),
    );
  }

  Widget _buildCreateButton() {
    return Consumer<DebtProvider>(
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
              text: 'إضافة الدين',
              onPressed: _handleCreate,
              isLoading: provider.isCreating,
              size: ButtonSize.large,
            ),
          ],
        );
      },
    );
  }
}
