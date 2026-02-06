import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';

import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/core/utils/validators.dart';
// Removed unused LicenseKey imports
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/presentation/widgets/common/double_back_to_exit_wrapper.dart';

class StoreRegistrationScreen extends StatefulWidget {
  const StoreRegistrationScreen({super.key});

  @override
  State<StoreRegistrationScreen> createState() =>
      _StoreRegistrationScreenState();
}

class _StoreRegistrationScreenState extends State<StoreRegistrationScreen> {
  // State
  int _registrationMethod = 0; // 0: Email, 1: Google

  // Controllers
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>(); // Renamed from _formKeyStep2
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storePasswordController =
      TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // New Controllers for Email Registration
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _ownerEmailController = TextEditingController();
  final TextEditingController _ownerPasswordController =
      TextEditingController();

  // Logic
  // LicenseKeyRepository _licenseKeyRepository = LicenseKeyRepository(); // Removed
  // LicenseKeyModel? _verifiedKey; // Removed
  // bool _isVerifyingLicense = false; // Removed
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _storeNameController.dispose();
    _storePasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Actions ---

  // Removed _verifyLicense method

  Future<void> _handleCreateAccount() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoading) return;

    // License check removed

    String? storeId;

    try {
      if (_registrationMethod == 1) {
        // --- Google Registration ---
        await authProvider.loginWithGoogleOrNull();
        final currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser == null) {
          ToastUtils.showError('فشل تسجيل الدخول بجوجل');
          return;
        }

        storeId = await authProvider.registerStoreWithGoogle(
          storeName: _storeNameController.text,
          storePassword: _storePasswordController.text,
        );
      } else {
        // --- Email Registration ---
        storeId = await authProvider.registerStoreWithEmail(
          ownerName: _ownerNameController.text,
          email: _ownerEmailController.text.trim(),
          password: _ownerPasswordController.text,
          storeName: _storeNameController.text,
          storePassword: _storePasswordController.text,
        );
      }
    } on DeviceLimitExceededException catch (e) {
      ToastUtils.showError(e.message);
    } on EmailAlreadyInUseException catch (e) {
      ToastUtils.showError(e.message);
    } on WeakPasswordException catch (e) {
      ToastUtils.showError(e.message);
    } on NetworkException catch (e) {
      ToastUtils.showError(e.message);
    } on StoreInactiveException catch (e) {
      ToastUtils.showError(e.message);
    } catch (e) {
      ToastUtils.showError(
          e is AppException ? e.message : "حدث خطأ غير متوقع: $e");
    }

    // --- Success Handler ---
    if (storeId != null && mounted) {
      // Activation logic removed as it's auto-trial now

      Navigator.of(context).pushNamedAndRemoveUntil(
          RouteConstants.ownerDashboard, (route) => false);
      ToastUtils.showSuccess(AppLocalizations.of(context)!.loginSuccess);
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return DoubleBackToExitWrapper(
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg(context),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildRegistrationForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Removed _buildStep1

  Widget _buildRegistrationForm() {
    final authProvider = Provider.of<AuthProvider>(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بيانات المتجر',
            style: AppTextStyles.h1.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 8),
          Text(
            'قم بإنشاء متجرك الجديد وابدأ فترتك التجريبية',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Registration Method Toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _registrationMethod = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _registrationMethod == 0
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _registrationMethod == 0
                            ? AppColors.primary
                            : AppColors.divider(context),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'البريد الإلكتروني',
                      style: TextStyle(
                        color: _registrationMethod == 0
                            ? AppColors.primary
                            : AppColors.textSecondary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _registrationMethod = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _registrationMethod == 1
                          ? AppColors.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _registrationMethod == 1
                            ? AppColors.primary
                            : AppColors.divider(context),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(FontAwesomeIcons.google, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Google',
                          style: TextStyle(
                            color: _registrationMethod == 1
                                ? AppColors.primary
                                : AppColors.textSecondary(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Common Store Fields
          CustomTextField(
            controller: _storeNameController,
            labelText: AppLocalizations.of(context)!.storeName,
            prefixIcon: const Icon(Icons.store),
            validator: Validators.validateStoreName,
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _storePasswordController,
            labelText: AppLocalizations.of(context)!.storePassword,
            prefixIcon: const Icon(Icons.lock),
            validator: Validators.validateStorePassword,
            keyboardType: TextInputType.number,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _confirmPasswordController,
            labelText: AppLocalizations.of(context)!.confirmPassword,
            prefixIcon: const Icon(Icons.lock_outline),
            validator: (val) => Validators.validateConfirmPassword(
                val, _storePasswordController.text),
            keyboardType: TextInputType.number,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),

          // Specific Fields for Email Registration
          if (_registrationMethod == 0) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text('بيانات المالك', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _ownerNameController,
              labelText: 'اسم المالك',
              prefixIcon: const Icon(Icons.person),
              validator: Validators.validateName,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _ownerEmailController,
              labelText: 'البريد الإلكتروني',
              prefixIcon: const Icon(Icons.email),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _ownerPasswordController,
              labelText: 'كلمة مرور الحساب',
              prefixIcon: const Icon(Icons.lock_outline),
              validator: Validators.validatePassword,
              obscureText: true,
            ),
          ],

          const SizedBox(height: 32),
          CustomButton(
            text: _registrationMethod == 1
                ? 'تسجيل باستخدام Google'
                : 'إنشاء الحساب',
            onPressed: authProvider.isLoading ? null : _handleCreateAccount,
            isLoading: authProvider.isLoading,
            icon: _registrationMethod == 1
                ? const FaIcon(FontAwesomeIcons.google,
                    color: Colors.white, size: 18)
                : null,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---
}
