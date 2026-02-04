import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/core/utils/validators.dart';
import 'package:walletmanager/data/repositories/license_key_repository.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/providers/auth_provider.dart';

class LicenseExpiredScreen extends StatefulWidget {
  const LicenseExpiredScreen({super.key});

  @override
  State<LicenseExpiredScreen> createState() => _LicenseExpiredScreenState();
}

class _LicenseExpiredScreenState extends State<LicenseExpiredScreen> {
  final _licenseController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final LicenseKeyRepository _licenseKeyRepository = LicenseKeyRepository();

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _handleRenewal() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final keyInput = _licenseController.text.trim().toUpperCase();
    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final storeId = authProvider.currentStoreId;

      if (storeId == null) {
        ToastUtils.showError("خطأ: لم يتم العثور على معرف المتجر");
        return;
      }

      // 1. Verify Key Not Used
      final keyModel = await _licenseKeyRepository.verifyLicenseKey(keyInput);
      if (keyModel == null) {
        ToastUtils.showError("مفتاح الترخيص غير صحيح");
        return;
      }
      if (keyModel.isUsed) {
        ToastUtils.showError("مفتاح الترخيص مستخدم بالفعل");
        return;
      }

      // 2. Activate Key
      await _licenseKeyRepository.activateLicenseKey(
        keyId: keyModel.keyId,
        storeId: storeId,
      );

      ToastUtils.showSuccess("تم تجديد الاشتراك بنجاح!");

      // 3. Refresh User Data to update status in Provider
      await authProvider.refreshUserData();

      // If refreshUserData updates status to authenticated,
      // the AppRouter (or Consumer in app.dart) should handle navigation.
    } catch (e) {
      ToastUtils.showError("فشل التجديد: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _contactSupport() async {
    const phone = '201091264053';
    final message = "مرحباً، انتهت فترة اشتراكي وأرغب في التجديد.";
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      ToastUtils.showError('تعذر فتح واتساب');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.lock_clock,
                size: 80,
                color: AppColors.error,
              ),
              const SizedBox(height: 24),
              Text(
                'انتهت الفترة التجريبية',
                style: AppTextStyles.h1.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'يرجى تجديد الاشتراك للاستمرار في استخدام التطبيق والوصول إلى بياناتك.',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: CustomTextField(
                  controller: _licenseController,
                  labelText: 'مفتاح الترخيص الجديد',
                  hintText: 'WALLET-2025-XXXX-XXXX',
                  prefixIcon: const Icon(Icons.vpn_key),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 21,
                  validator: Validators.validateLicenseKey,
                ),
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'تفعيل الاشتراك',
                onPressed: _isLoading ? null : _handleRenewal,
                isLoading: _isLoading,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _contactSupport,
                icon: const FaIcon(FontAwesomeIcons.whatsapp,
                    color: Colors.green),
                label: Text(
                  'تواصل معنا للتجديد',
                  style: TextStyle(color: AppColors.textPrimary(context)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.divider(context)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () {
                  context.read<AuthProvider>().logout();
                },
                child: const Text('تسجيل الخروج',
                    style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
