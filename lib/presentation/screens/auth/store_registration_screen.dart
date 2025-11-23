import 'package:walletmanager/core/utils/dialog_utils.dart';
import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/route_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../../data/models/license_key_model.dart';
import '../../../data/repositories/license_key_repository.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class StoreRegistrationScreen extends StatefulWidget {
  const StoreRegistrationScreen({super.key});

  @override
  State<StoreRegistrationScreen> createState() =>
      _StoreRegistrationScreenState();
}

class _StoreRegistrationScreenState extends State<StoreRegistrationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _storeNameController;
  late final TextEditingController _storePasswordController;
  late final TextEditingController _confirmPasswordController;
  final _licenseKeyController = TextEditingController();
  bool _isVerifying = false;
  LicenseKeyModel? _verifiedKey;
  late final LicenseKeyRepository _licenseKeyRepository;
  int _currentStep = 0;

  bool _isRegistering = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _storeNameController = TextEditingController();
    _storePasswordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _licenseKeyRepository = LicenseKeyRepository();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).clearError();
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storePasswordController.dispose();
    _confirmPasswordController.dispose();
    _licenseKeyController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _formKey.currentState?.reset();
      _storeNameController.clear();
      _storePasswordController.clear();
      _confirmPasswordController.clear();
      _licenseKeyController.clear();
      Provider.of<AuthProvider>(context, listen: false).clearError();
    });
  }

  void _showContactDialog() {
    DialogUtils.showOptionsDialog(
      context,
      title: AppLocalizations.of(context)!.contactUs,
      options: [
        _buildContactRow(
          context: context,
          icon: Icons.phone,
          label: AppLocalizations.of(context)!.whatsapp,
          value: '01091264053',
          onTap: () {
            Navigator.of(context).pop();
            _launchWhatsApp();
          },
        ),
        const SizedBox(height: 8),
        _buildContactRow(
          context: context,
          icon: Icons.email,
          label: AppLocalizations.of(context)!.email,
          value: 'amrloulah2021@gmail.com',
          onTap: () {
            Navigator.of(context).pop();
            _launchEmail();
          },
        ),
      ],
    );
  }

  void _showLicenseExpiredDialog() {
    DialogUtils.showConfirmDialog(
      context,
      title: AppLocalizations.of(context)!.licenseExpired,
      message: AppLocalizations.of(context)!.licenseExpiredMessage,
      confirmText: AppLocalizations.of(context)!.renewLicense,
      cancelText: AppLocalizations.of(context)!.cancel,
      type: DialogType.warning,
    ).then((confirmed) {
      if (confirmed == true) {
        _showContactDialog();
      }
    });
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isLoading) return;

    try {
      final loginSuccess = await authProvider.loginWithGoogleOrNull();

      if (loginSuccess) {
        // The Consumer widget will handle navigation
        return;
      }

      if (!_isRegistering) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.noAccountLinked),
              backgroundColor: Colors.blue,
            ),
          );

          setState(() {
            _isRegistering = true;
            _currentStep = 0;
          });
        }
        return;
      }

      if (_verifiedKey == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.licenseKeyError),
              backgroundColor: Colors.red,
            ),
          );

          setState(() {
            _currentStep = 1;
          });
        }
        return;
      }

      final storeId = await authProvider.registerStoreWithGoogle(
        storeName: _storeNameController.text,
        storePassword: _storePasswordController.text,
        licenseKey: _verifiedKey!.licenseKey,
        licenseKeyId: _verifiedKey!.keyId,
      );

      if (storeId != null && mounted) {
        try {
          await _licenseKeyRepository.activateLicenseKey(
            keyId: _verifiedKey!.keyId,
            storeId: storeId,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.activationFailed),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } on StoreInactiveException catch (e) {
      ToastUtils.showError(e.message);
    } on LicenseExpiredException {
      _showLicenseExpiredDialog();
    } catch (e) {
      // Handle other exceptions if necessary
    }
  }

  void _showSuccessMessage(String message) {
    ToastUtils.showSuccess(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          if (authProvider.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacementNamed(
                  context, RouteConstants.ownerDashboard);
              _showSuccessMessage(AppLocalizations.of(context)!.loginSuccess);
            });
            return const Center(child: CircularProgressIndicator());
          }
          return SafeArea(
            child: Center(
              child: _isRegistering
                  ? Form(key: _formKey, child: _buildCurrentStep())
                  : _buildLoginUI(authProvider),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoginUI(AuthProvider authProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.wallet, size: 80, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.walletManager,
              textAlign: TextAlign.center, style: AppTextStyles.h1),
          Text(AppLocalizations.of(context)!.manageWallets,
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          const SizedBox(height: 32),
          CustomButton(
            text: AppLocalizations.of(context)!.loginWithGoogle,
            onPressed: _handleGoogleSignIn,
            isLoading: authProvider.isLoading,
            icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
          ),
          if (authProvider.status == AuthStatus.error &&
              authProvider.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                authProvider.errorMessage!,
                textAlign: TextAlign.center,
                style:
                    AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 24),
          _buildEmployeeLoginLink(),
          _buildRenewLicenseLink(),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStoreInfoStep();
      case 1:
        return _buildLicenseKeyStep();
      case 2:
        return _buildGoogleSignInStep();
      default:
        return _buildStoreInfoStep();
    }
  }

  Widget _buildStoreInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.wallet, size: 80, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.createAccount,
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          Text(AppLocalizations.of(context)!.step1StoreInfo,
              textAlign: TextAlign.center, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 32),
          ..._buildRegistrationForm(),
          const SizedBox(height: 24),
          CustomButton(
            text: AppLocalizations.of(context)!.next,
            onPressed: () {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() => _currentStep++);
              }
            },
          ),
          const SizedBox(height: 24),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildToggleModeButton(),
          const SizedBox(height: 16),
          _buildEmployeeLoginLink(),
          _buildRenewLicenseLink(),
        ],
      ),
    );
  }

  Widget _buildLicenseKeyStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppLocalizations.of(context)!.step2LicenseKey,
                style: AppTextStyles.h2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Card(
              color: AppColors.info.withAlpha((0.1 * 255).round()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: 48),
                    const SizedBox(height: 12),
                    Text(AppLocalizations.of(context)!.getLicenseKey,
                        style: AppTextStyles.h3, textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.contactUsAt,
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    _buildContactRow(
                      context: context,
                      icon: Icons.phone,
                      label: AppLocalizations.of(context)!.whatsapp,
                      value: '01091264053',
                      onTap: () => _launchWhatsApp(),
                    ),
                    const SizedBox(height: 8),
                    _buildContactRow(
                      context: context,
                      icon: Icons.email,
                      label: AppLocalizations.of(context)!.email,
                      value: 'amrloulah2021@gmail.com',
                      onTap: () => _launchEmail(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              controller: _licenseKeyController,
              labelText: AppLocalizations.of(context)!.licenseKey,
              hintText: 'WALLET-2025-XXXX-XXXX',
              prefixIcon: const Icon(Icons.vpn_key),
              textCapitalization: TextCapitalization.characters,
              validator: Validators.validateLicenseKey,
              maxLength: 21,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.enterLicenseKey,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary(context)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24), // Replaced Spacer with a fixed size box

            if (_verifiedKey != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Center(
                    child: Text(AppLocalizations.of(context)!.verifiedSuccess,
                        style: AppTextStyles.bodyLarge
                            .copyWith(color: AppColors.success))),
              ),
            CustomButton(
              text: _verifiedKey == null
                  ? AppLocalizations.of(context)!.verifyKey
                  : AppLocalizations.of(context)!.next,
              onPressed: _verifiedKey != null
                  ? () => setState(() => _currentStep++)
                  : (_isVerifying || _licenseKeyController.text.trim().isEmpty
                      ? null
                      : _verifyLicenseKey),
              isLoading: _isVerifying,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: Text(AppLocalizations.of(context)!.back),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInStep() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.wallet, size: 80, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.step3Google,
              textAlign: TextAlign.center, style: AppTextStyles.h2),
          Text(AppLocalizations.of(context)!.linkGoogle,
              textAlign: TextAlign.center, style: AppTextStyles.bodyLarge),
          const SizedBox(height: 32),
          CustomButton(
            text: AppLocalizations.of(context)!.createAccountGoogle,
            onPressed: _handleGoogleSignIn,
            isLoading: authProvider.isLoading,
            icon: const FaIcon(FontAwesomeIcons.google, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _currentStep--),
            child: Text(AppLocalizations.of(context)!.back),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyLicenseKey() async {
    final licenseKey = _licenseKeyController.text.toUpperCase();
    if (licenseKey.isEmpty || licenseKey.length != 21) {
      ToastUtils.showError(AppLocalizations.of(context)!.enterValidLicense);
      return;
    }

    setState(() => _isVerifying = true);

    try {
      final keyModel = await _licenseKeyRepository.verifyLicenseKey(licenseKey);

      if (keyModel == null) {
        ToastUtils.showError(AppLocalizations.of(context)!.invalidLicense);
        return;
      }

      if (keyModel.isUsed) {
        ToastUtils.showError(AppLocalizations.of(context)!.licenseUsed);
        return;
      }

      setState(() => _verifiedKey = keyModel);
      ToastUtils.showSuccess(AppLocalizations.of(context)!.verifySuccess);
      // await _completeRegistration(); // This will be called on button press now
    } catch (e) {
      ToastUtils.showError(AppLocalizations.of(context)!.errorVerifying);
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Widget _buildContactRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTextStyles.labelSmall
                          .copyWith(color: Colors.black)),
                  Text(
                    value,
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: Colors.black),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _launchWhatsApp() async {
    const phone = '201091264053';
    final message = AppLocalizations.of(context)!.whatsappMessageLicense;
    final encodedMessage = Uri.encodeComponent(message);
    final url = 'https://wa.me/$phone?text=$encodedMessage';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ToastUtils.showError(AppLocalizations.of(context)!.errorOpenWhatsapp);
    }
  }

  Future<void> _launchEmail() async {
    const email = 'amrloulah2021@gmail.com';
    final subject = AppLocalizations.of(context)!.emailSubjectLicense;
    final body = AppLocalizations.of(context)!.emailBodyLicense;
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      if (mounted)
        ToastUtils.showError(AppLocalizations.of(context)!.errorOpenEmail);
    }
  }

  List<Widget> _buildRegistrationForm() {
    return [
      CustomTextField(
        controller: _storeNameController,
        labelText: AppLocalizations.of(context)!.storeName,
        hintText: AppLocalizations.of(context)!.storeNameHint,
        validator: Validators.validateStoreName,
        keyboardType: TextInputType.name,
        prefixIcon: const Icon(Icons.store),
      ),
      const SizedBox(height: 16),
      CustomTextField(
        controller: _storePasswordController,
        labelText: AppLocalizations.of(context)!.storePassword,
        hintText: AppLocalizations.of(context)!.storePasswordHint,
        validator: Validators.validateStorePassword,
        keyboardType: TextInputType.number,
        obscureText: _obscurePassword,
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon:
              Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 16),
      CustomTextField(
        controller: _confirmPasswordController,
        labelText: AppLocalizations.of(context)!.confirmPassword,
        hintText: AppLocalizations.of(context)!.confirmPasswordHint,
        validator: (value) => Validators.validateConfirmPassword(
            value, _storePasswordController.text),
        keyboardType: TextInputType.number,
        obscureText: _obscureConfirmPassword,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscureConfirmPassword
              ? Icons.visibility_off
              : Icons.visibility),
          onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
    ];
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(AppLocalizations.of(context)!.or,
              style: AppTextStyles.bodyMedium),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildToggleModeButton() {
    return TextButton(
      onPressed: _toggleMode,
      child: Text(
        _isRegistering
            ? AppLocalizations.of(context)!.haveAccount
            : AppLocalizations.of(context)!.noAccount,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
      ),
    );
  }

  Widget _buildEmployeeLoginLink() {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, RouteConstants.employeeLogin);
      },
      child: Text(
        AppLocalizations.of(context)!.loginAsEmployee,
        style: AppTextStyles.labelMedium,
      ),
    );
  }

  Widget _buildRenewLicenseLink() {
    return TextButton(
      onPressed: () => _showContactDialog(),
      child: Text(
        AppLocalizations.of(context)!.contactToRenew,
        style: AppTextStyles.labelMedium,
      ),
    );
  }
}
