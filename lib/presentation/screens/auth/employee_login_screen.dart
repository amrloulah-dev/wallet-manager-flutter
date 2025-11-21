import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/utils/dialog_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employee_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';

enum _LoginStep { password, pin, google }

class EmployeeLoginScreen extends StatefulWidget {
  const EmployeeLoginScreen({super.key});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storePasswordController = TextEditingController();
  final _storePasswordFocus = FocusNode();

  _LoginStep _currentStep = _LoginStep.password;
  String? _verifiedStoreId;
  UserModel? _verifiedEmployee;
  String _enteredPin = '';
  final int _pinLength = 4;

  bool _isLoading = false;

  @override
  void dispose() {
    _storePasswordController.dispose();
    _storePasswordFocus.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  // Step 1: Verify the store password
  Future<void> _verifyStorePassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _setLoading(true);

    final authProvider = context.read<AuthProvider>();
    final storeId = await authProvider.verifyStorePassword(_storePasswordController.text.trim());

    if (storeId != null) {
      setState(() {
        _verifiedStoreId = storeId;
        _currentStep = _LoginStep.pin;
      });
    } else {
      if (mounted) {
        ToastUtils.showError(authProvider.errorMessage ?? 'كلمة سر المحل غير صحيحة');
      }
    }
    _setLoading(false);
  }

  // Step 2: Verify the employee's PIN
  Future<void> _verifyPin() async {
    if (_verifiedStoreId == null) return;
    _setLoading(true);

    final employeeProvider = context.read<EmployeeProvider>();
    final employee = await employeeProvider.getEmployeeByPIN(
      storeId: _verifiedStoreId!,
      pin: _enteredPin,
    );

    if (employee != null) {
      setState(() {
        _verifiedEmployee = employee;
        _currentStep = _LoginStep.google;
      });
    } else {
      setState(() => _enteredPin = '');
      if (mounted) {
        ToastUtils.showError(employeeProvider.errorMessage ?? 'الرقم السري غير صحيح');
      }
    }
    _setLoading(false);
  }

  // Step 3: Sign in with the owner's Google account and finalize
  Future<void> _handleGoogleSignInAndFinalize() async {
    if (_verifiedStoreId == null || _verifiedEmployee == null) return;
    _setLoading(true);

    final authProvider = context.read<AuthProvider>();
    try {
      final success = await authProvider.loginWithGoogleOrNull();

      if (success) {
        if (authProvider.firebaseUser?.uid == _verifiedStoreId) {
          // Google UID matches the store owner, proceed to finalize
          await authProvider.finalizeEmployeeSession(employee: _verifiedEmployee!);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, RouteConstants.ownerDashboard);
          if (mounted && authProvider.isAuthenticated) {
            ToastUtils.showSuccess('مرحباً ${_verifiedEmployee!.fullName}');
          }
        } else {
          // Wrong Google account signed in
          await authProvider.logout();
          if (mounted) {
            ToastUtils.showError('يرجى تسجيل الدخول بحساب جوجل الخاص بالمتجر.');
          }
        }
      } else {
        if (mounted && authProvider.errorMessage != null) {
          ToastUtils.showError(authProvider.errorMessage!);
        }
      }
    } on StoreInactiveException catch (e) {
      ToastUtils.showError(e.message);
    } on LicenseExpiredException {
      _showLicenseExpiredDialog();
    } catch (e) {
      ToastUtils.showError('حدث خطأ غير متوقع.');
    }
    _setLoading(false);
  }

  void _showLicenseExpiredDialog() {
    DialogUtils.showConfirmDialog(
      context,
      title: 'الترخيص منتهي',
      message: 'يجب تجديد الترخيص للمتابعة.',
      confirmText: 'تواصل للتجديد',
      cancelText: 'إلغاء',
      type: DialogType.warning,
    ).then((confirmed) {
      if (confirmed == true) {
        // Implement renewal logic or contact support
      }
    });
  }

  // --- UI Helper Methods ---

  void _onNumberTap(String number) {
    if (_enteredPin.length < _pinLength) {
      HapticFeedback.lightImpact();
      setState(() => _enteredPin += number);
      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  void _resetToStep(_LoginStep step) {
    setState(() {
      _currentStep = step;
      if (step == _LoginStep.password) {
        _verifiedStoreId = null;
        _storePasswordController.clear();
        context.read<AuthProvider>().logout();
      }
      if (step == _LoginStep.pin) {
         context.read<AuthProvider>().logout();
      }
      _verifiedEmployee = null;
      _enteredPin = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل دخول الموظف'),
        leading: _currentStep != _LoginStep.password
            ? BackButton(onPressed: () => _resetToStep(_LoginStep.values[_currentStep.index - 1]))
            : null,
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'جاري تسجيل الدخول...')
          : SafeArea(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildCurrentStepWidget(),
                      ),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case _LoginStep.password:
        return _buildStorePasswordStep();
      case _LoginStep.pin:
        return _buildPinEntryStep();
      case _LoginStep.google:
        return _buildGoogleSignInStep();
    }
  }

  Widget _buildHeader() {
    String title;
    IconData icon;
    switch (_currentStep) {
      case _LoginStep.password:
        title = 'الخطوة 1: أدخل كلمة سر المتجر';
        icon = Icons.store_outlined;
        break;
      case _LoginStep.pin:
        title = 'الخطوة 2: أدخل الرقم السري الخاص بك';
        icon = Icons.pin_outlined;
        break;
      case _LoginStep.google:
        title = 'الخطوة 3: سجل بحساب جوجل الخاص بالمتجر';
        icon = FontAwesomeIcons.google;
        break;
    }
    return Column(
      children: [
        Icon(icon, size: 64, color: AppColors.primary),
        const SizedBox(height: 16),
        Text('تسجيل دخول الموظف', style: AppTextStyles.h2, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(title, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary(context)), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildStorePasswordStep() {
    return Column(
      key: const ValueKey('password_step'),
      children: [
        CustomTextField(
          controller: _storePasswordController,
          focusNode: _storePasswordFocus,
          labelText: 'كلمة سر المتجر',
          hintText: 'أدخل كلمة سر المتجر المكونة من 6 أرقام',
          validator: Validators.validateStorePassword,
          keyboardType: TextInputType.number,
          obscureText: true,
          prefixIcon: const Icon(Icons.lock_outline),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
        ),
        const SizedBox(height: 24),
        CustomButton(
          text: 'تحقق',
          onPressed: _verifyStorePassword,
          icon: const Icon(Icons.verified_user_outlined),
        ),
      ],
    );
  }

  Widget _buildPinEntryStep() {
    return Column(
      key: const ValueKey('pin_step'),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pinLength, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < _enteredPin.length ? AppColors.primary : AppColors.surface(context),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
            );
          }),
        ),
        const SizedBox(height: 32),
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 16),
        _buildKeypadRow(['', '0', 'backspace']),
      ],
    );
  }

  Widget _buildGoogleSignInStep() {
    return Column(
      key: const ValueKey('google_step'),
      children: [
        const SizedBox(height: 32),
        CustomButton(
          text: 'تسجيل الدخول عبر جوجل',
          onPressed: _handleGoogleSignInAndFinalize,
          icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 72, height: 72);
        if (key == 'backspace') {
          return _buildKeypadButton(
            child: const Icon(Icons.backspace_outlined, size: 28),
            onTap: _onBackspace,
          );
        }
        return _buildKeypadButton(
          child: Text(key, style: AppTextStyles.h1),
          onTap: () => _onNumberTap(key),
        );
      }).toList(),
    );
  }

  Widget _buildKeypadButton({required Widget child, required VoidCallback onTap}) {
    return SizedBox(
      width: 72,
      height: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildFooter() {
    return TextButton(
      onPressed: () => Navigator.pushReplacementNamed(context, RouteConstants.storeRegistration),
      child: const Text('هل أنت مالك المتجر؟ تسجيل الدخول من هنا'),
    );
  }
}