import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';

import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/core/utils/validators.dart';
import 'package:walletmanager/data/models/license_key_model.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/providers/auth_provider.dart';

class StoreRegistrationScreen extends StatefulWidget {
  const StoreRegistrationScreen({super.key});

  @override
  State<StoreRegistrationScreen> createState() =>
      _StoreRegistrationScreenState();
}

class _StoreRegistrationScreenState extends State<StoreRegistrationScreen> {
  // State
  int _currentStep = 0; // 0: License, 1: Store Info

  // Controllers
  final GlobalKey<FormState> _formKeyStep2 = GlobalKey<FormState>();
  final TextEditingController _licenseKeyController = TextEditingController();
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _storePasswordController =
      TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // Logic
  final LicenseKeyRepository _licenseKeyRepository = LicenseKeyRepository();
  LicenseKeyModel? _verifiedKey;
  bool _isVerifyingLicense = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _licenseKeyController.dispose();
    _storeNameController.dispose();
    _storePasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _verifyLicense() async {
    final keyInput = _licenseKeyController.text.trim().toUpperCase();
    if (keyInput.isEmpty || keyInput.length != 21) {
      ToastUtils.showError('يرجى إدخال مفتاح ترخيص صحيح (21 حرف)');
      return;
    }

    setState(() => _isVerifyingLicense = true);

    try {
      final keyModel = await _licenseKeyRepository.verifyLicenseKey(keyInput);

      if (keyModel == null) {
        ToastUtils.showError(AppLocalizations.of(context)!.invalidLicense);
        return;
      }

      if (keyModel.isUsed) {
        ToastUtils.showError(AppLocalizations.of(context)!.licenseUsed);
        return;
      }

      setState(() {
        _verifiedKey = keyModel;
        _currentStep = 1; // Move to Step 2
      });
      ToastUtils.showSuccess(AppLocalizations.of(context)!.verifySuccess);
    } catch (e) {
      ToastUtils.showError(AppLocalizations.of(context)!.errorVerifying);
    } finally {
      if (mounted) setState(() => _isVerifyingLicense = false);
    }
  }

  Future<void> _handleCreateAccount() async {
    print('📍 UI: Button Clicked - Starting _handleCreateAccount');

    if (!(_formKeyStep2.currentState?.validate() ?? false)) {
      print('❌ UI: Validation Failed (Form is invalid)');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoading) {
      print('⚠️ UI: Ignored click (Provider is loading)');
      return;
    }

      Provider.of<AuthProvider>(context, listen: false);

    // 1. Google Sign In
    print('👉 UI: Calling authProvider.loginWithGoogleOrNull()...');
    
    // استدعاء الدالة (سواء رجعت true أو false مش هيفرق معانا دلوقتي)
    await authProvider.loginWithGoogleOrNull();

    // التحقق الحقيقي: هل المستخدم موجود في فايربيس؟
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      print('⛔ UI: Google Sign-In failed (User is null).');
      ToastUtils.showError('فشل تسجيل الدخول بجوجل');
      return;
    }

    // 2. Register Store
    print('👉 UI: Checking License Key...');
    if (_verifiedKey == null) {
      print('❌ UI: License Key is NULL');
      ToastUtils.showError(AppLocalizations.of(context)!.licenseKeyError);
      return;
    }

    try {
      print('🚀 UI: Calling registerStoreWithGoogle (The Critical Step)...');
      
      final storeId = await authProvider.registerStoreWithGoogle(
        storeName: _storeNameController.text,
        storePassword: _storePasswordController.text,
        licenseKey: _verifiedKey!.licenseKey,
        licenseKeyId: _verifiedKey!.keyId,
      );

      print('✅ UI: registerStoreWithGoogle finished. StoreId: $storeId');

      if (storeId != null && mounted) {
        // 3. Activate License
        print('👉 UI: Activating License...');
        try {
          await _licenseKeyRepository.activateLicenseKey(
            keyId: _verifiedKey!.keyId,
            storeId: storeId,
          );
          print('✅ UI: License Activated.');
        } catch (e) {
          print('⚠️ UI: License activation warning: $e');
        }

        print('🎉 UI: Navigating to Dashboard...');
        Navigator.of(context).pushNamedAndRemoveUntil(
            RouteConstants.ownerDashboard, (route) => false);
        ToastUtils.showSuccess(AppLocalizations.of(context)!.loginSuccess);
      } else {
        print('❌ UI: StoreId is null!');
      }
    } on StoreInactiveException catch (e) {
      print('🚨 UI Error (StoreInactive): ${e.message}');
      ToastUtils.showError(e.message);
    } catch (e) {
      print('🚨 UI Error (Unexpected): $e');
      ToastUtils.showError('حدث خطأ غير متوقع: $e');
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
          onPressed: () {
            if (_currentStep == 1) {
              setState(() => _currentStep = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentStep == 0) _buildStep1() else _buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تفعيل الترخيص',
          style: AppTextStyles.h1.copyWith(fontSize: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'الخطوة 1 من 2',
          style: AppTextStyles.bodyMedium
              .copyWith(color: AppColors.textSecondary(context)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // Contact Info Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: AppColors.surface(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'للحصول على مفتاح الترخيص، تواصل معنا:',
                  style: AppTextStyles.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _buildContactRow(
                  icon: Icons.phone,
                  label: 'WhatsApp',
                  value: '01091264053',
                  onTap: () => _launchWhatsApp(),
                ),
                const SizedBox(height: 8),
                _buildContactRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: 'amrloulah2021@gmail.com',
                  onTap: () => _launchEmail(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),

        CustomTextField(
          controller: _licenseKeyController,
          labelText: 'مفتاح الترخيص',
          hintText: 'WALLET-2025-XXXX-XXXX',
          prefixIcon: const Icon(Icons.vpn_key),
          textCapitalization: TextCapitalization.characters,
          maxLength: 21,
          validator: Validators.validateLicenseKey,
        ),
        const SizedBox(height: 24),

        CustomButton(
          text: 'تحقق',
          onPressed: _isVerifyingLicense ? null : _verifyLicense,
          isLoading: _isVerifyingLicense,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final authProvider = Provider.of<AuthProvider>(context);
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'بيانات المتجر',
            style: AppTextStyles.h1.copyWith(fontSize: 28),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'الخطوة 2 من 2',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
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
          const SizedBox(height: 32),
          CustomButton(
            text: 'إنشاء الحساب',
            onPressed: authProvider.isLoading ? null : _handleCreateAccount,
            isLoading: authProvider.isLoading,
            icon: const FaIcon(FontAwesomeIcons.google,
                color: Colors.white, size: 18),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text('الرجوع'),
          ),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.divider(context)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text('$label: $value', style: AppTextStyles.bodyMedium),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    const phone = '201091264053';
    final message = AppLocalizations.of(context)!.whatsappMessageLicense;
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ToastUtils.showError('Could not launch WhatsApp');
    }
  }

  Future<void> _launchEmail() async {
    const email = 'amrloulah2021@gmail.com';
    final subject = AppLocalizations.of(context)!.emailSubjectLicense;
    final body = AppLocalizations.of(context)!.emailBodyLicense;
    final uri = Uri(
        scheme: 'mailto',
        path: email,
        query:
            'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) ToastUtils.showError('Could not launch Email');
    }
  }
}
