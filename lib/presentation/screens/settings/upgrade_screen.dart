import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/core/utils/date_helper.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';

class UpgradeScreen extends StatelessWidget {
  final bool isTrial;

  const UpgradeScreen({super.key, required this.isTrial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isTrial ? "الترقية للنسخة الكاملة" : "معلومات الترخيص"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: isTrial ? _buildTrialUI(context) : _buildPremiumUI(context),
      ),
    );
  }

  Widget _buildTrialUI(BuildContext context) {
    final TextEditingController keyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Column(
      children: [
        // Contact Info Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Icon(Icons.support_agent,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  'للحصول على مفتاح التفعيل، يرجى التواصل معنا',
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _buildContactButton(
                  context,
                  icon: Icons.phone,
                  label: 'تواصل عبر واتساب',
                  onTap: () => _launchWhatsApp(context),
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                _buildContactButton(
                  context,
                  icon: Icons.email,
                  label: 'تواصل عبر البريد الإلكتروني',
                  onTap: () => _launchEmail(context),
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Activation Form
        Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("تفعيل الاشتراك", style: AppTextStyles.h3),
              const SizedBox(height: 16),
              CustomTextField(
                labelText: "مفتاح التفعيل",
                controller: keyController,
                hintText: "أدخل مفتاح التفعيل هنا",
                prefixIcon: const Icon(Icons.vpn_key_outlined),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال مفتاح التفعيل';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return CustomButton(
                    text: "تفعيل",
                    isLoading: auth.isLoading,
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        try {
                          await auth
                              .activateNewLicense(keyController.text.trim());
                          if (context.mounted) {
                            ToastUtils.showSuccess('تم تفعيل الاشتراك بنجاح!');
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          ToastUtils.showError(
                              auth.errorMessage ?? 'فشل التفعيل');
                        }
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumUI(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final licenseKey = authProvider.licenseKey;
        final expiryDate = authProvider.licenseExpiryDate;
        final daysRemaining =
            authProvider.currentStore?.license.daysRemaining ?? 0;

        return Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        size: 64, color: AppColors.success),
                    const SizedBox(height: 16),
                    Text(
                      'النسخة الكاملة مفعلة',
                      style:
                          AppTextStyles.h2.copyWith(color: AppColors.success),
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(context, "مفتاح الترخيص", licenseKey),
                    const SizedBox(height: 16),
                    _buildInfoRow(context, "تاريخ الانتهاء",
                        DateHelper.formatTimestamp(expiryDate)),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                        context, "الأيام المتبقية", "$daysRemaining يوم"),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: "تجديد الاشتراك",
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => _launchWhatsApp(context, isRenew: true),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary(context))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style:
                AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildContactButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.1),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(color: color),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context,
      {bool isRenew = false}) async {
    const phone = '201091264053';
    final message = isRenew
        ? "مرحباً، أرغب في تجديد اشتراكي في تطبيق مدير المحفظة."
        : "مرحباً، أرغب في الحصول على مفتاح تفعيل لتطبيق مدير المحفظة.";
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$phone?text=$encodedMessage';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        ToastUtils.showError("فشل فتح واتساب");
      }
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    const email = 'amrloulah2021@gmail.com';
    const subject = "طلب تفعيل النسخة الكاملة";
    const body = "مرحباً، أود الاستفسار عن كيفية الترقية للنسخة الكاملة.";
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      if (context.mounted) {
        ToastUtils.showError("فشل فتح البريد الإلكتروني");
      }
    }
  }
}
