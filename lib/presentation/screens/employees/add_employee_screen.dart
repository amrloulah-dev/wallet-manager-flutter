
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employee_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _pinFocus = FocusNode();
  final _confirmPinFocus = FocusNode();

  bool _isSubmitting = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();

    _fullNameFocus.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
    _confirmPinFocus.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    final authProvider = context.read<AuthProvider>();
    final employeeProvider = context.read<EmployeeProvider>();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _phoneController.text.trim();

    final maxEmployees = authProvider.currentStore?.settings.maxEmployees ?? 5;
    if (employeeProvider.employeesCount >= maxEmployees) {
      ToastUtils.showError('لقد وصلت إلى الحد الأقصى لعدد الموظفين');
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await employeeProvider.addEmployee(
      fullName: _fullNameController.text.trim(),
      phone: phone,
      pin: _pinController.text,
    );

    if (mounted) {
      if (success) {
        ToastUtils.showSuccess('تمت إضافة الموظف بنجاح');
        Navigator.pop(context, true);
      } else {
        ToastUtils.showError( 
            employeeProvider.errorMessage ?? 'حدث خطأ غير متوقع');
      }
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إضافة موظف جديد'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildEmployeeCountHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInfoNote(),
                      const SizedBox(height: 24),
                      _buildFormFields(),
                      const SizedBox(height: 32),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeCountHeader() {
    return Consumer2<EmployeeProvider, AuthProvider>(
      builder: (context, employeeProvider, authProvider, _) {
        final currentCount = employeeProvider.employeesCount;
        final maxEmployees = authProvider.currentStore?.settings.maxEmployees ?? 5;
        final isAtLimit = currentCount >= maxEmployees;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isAtLimit
              ? AppColors.error.withAlpha((0.1 * 255).round())
              : AppColors.primary.withAlpha((0.1 * 255).round()),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAtLimit ? Icons.error_outline : Icons.info_outline,
                color: isAtLimit ? AppColors.error : AppColors.primary,
              ),
              const SizedBox(width: 12),
              Text(
                'الموظفين الحاليين: $currentCount / $maxEmployees',
                style: AppTextStyles.labelMedium.copyWith(
                  color: isAtLimit ? AppColors.error : AppColors.primary,
                ),
              ),
              if (isAtLimit) ...[
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'تم الوصول للحد الأقصى',
                    style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.info.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'سيستخدم الموظف رقم الهاتف والرقم السري لتسجيل الدخول.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomTextField(
          controller: _fullNameController,
          focusNode: _fullNameFocus,
          labelText: 'الاسم الكامل',
          hintText: 'أدخل اسم الموظف',
          prefixIcon: const Icon(Icons.person_outline),
          validator: (value) => Validators.validateName(value),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_phoneFocus),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          labelText: 'رقم الهاتف',
          hintText: '01xxxxxxxxx',
          prefixIcon: const Icon(Icons.phone_outlined),
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 11,
          validator: Validators.validatePhoneNumber,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_pinFocus),
        ),
        const SizedBox(height: 24),
        Text('الرقم السري للموظف (PIN)', style: AppTextStyles.h3),
        const SizedBox(height: 12),
        CustomTextField(
          controller: _pinController,
          focusNode: _pinFocus,
          labelText: 'الرقم السري',
          hintText: '4 أرقام',
          prefixIcon: const Icon(Icons.pin_outlined),
          obscureText: _obscurePin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffixIcon: IconButton(
            icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
          validator: (value) => Validators.validatePin(value),
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_confirmPinFocus),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _confirmPinController,
          focusNode: _confirmPinFocus,
          labelText: 'تأكيد الرقم السري',
          hintText: 'أعد إدخال الرقم السري',
          prefixIcon: const Icon(Icons.lock_outline),
          obscureText: _obscureConfirmPin,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffixIcon: IconButton(
            icon: Icon(
                _obscureConfirmPin ? Icons.visibility_off : Icons.visibility),
            onPressed: () =>
                setState(() => _obscureConfirmPin = !_obscureConfirmPin),
          ),
          validator: (value) {
            if (value != _pinController.text) {
              return 'الرقمان غير متطابقان';
            }
            return null;
          },
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitForm(),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Consumer<EmployeeProvider>(
      builder: (context, provider, _) {
        final isAtLimit = provider.employeesCount >=
            (context.read<AuthProvider>().currentStore?.settings.maxEmployees ?? 5);

        return CustomButton(
          text: 'إضافة الموظف',
          onPressed: _isSubmitting || isAtLimit ? null : _submitForm,
          isLoading: _isSubmitting,
          icon: const Icon(Icons.person_add_alt_1),
          size: ButtonSize.large,
        );
      },
    );
  }
}
