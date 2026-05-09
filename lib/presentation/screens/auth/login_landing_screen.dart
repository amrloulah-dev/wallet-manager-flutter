import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/core/utils/error_mapper.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/core/utils/validators.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/presentation/widgets/common/double_back_to_exit_wrapper.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/errors/app_error_handler.dart';
import 'employee_login_screen.dart';
import '../../../l10n/arb/app_localizations.dart';

class LoginLandingScreen extends StatefulWidget {
  const LoginLandingScreen({super.key});

  @override
  State<LoginLandingScreen> createState() => _LoginLandingScreenState();
}

class _LoginLandingScreenState extends State<LoginLandingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _ownerFormKey = GlobalKey<FormState>();
  final _employeeFormKey = GlobalKey<FormState>();

  // Controllers
  final _ownerEmailController = TextEditingController();
  final _ownerPasswordController = TextEditingController();
  final _storeEmailController = TextEditingController(); // For Employee lookup

  bool _obscureOwnerPassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ownerEmailController.dispose();
    _ownerPasswordController.dispose();
    _storeEmailController.dispose();
    super.dispose();
  }

  // --- Actions ---

  Future<void> _handleOwnerLoginWithGoogle() async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

    final success = await authProvider.loginWithGoogleOrNull();
    if (success && mounted) {
      _navigateBasedOnRole(authProvider);
    } else if (mounted && authProvider.errorMessage != null) {
      ToastUtils.showError(authProvider.errorMessage!);
    }
  }

  Future<void> _handleOwnerLoginWithEmail() async {
    if (!_ownerFormKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

    try {
      await authProvider.loginOwnerWithEmail(
        _ownerEmailController.text.trim(),
        _ownerPasswordController.text,
      );

      if (mounted) {
        _navigateBasedOnRole(authProvider);
      }
    } on UserNotFoundException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'LoginLanding: UserNotFoundException');
      if (mounted) {
        ToastUtils.showError(
            ErrorMapper.getLocalizedString(context, 'auth_error_user_not_found'));
      }
    } on WrongPasswordException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'LoginLanding: WrongPasswordException');
      if (mounted) {
        ToastUtils.showError(
            ErrorMapper.getLocalizedString(context, 'auth_error_invalid_credentials'));
      }
    } on AuthException catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'LoginLanding: AuthException');
      if (mounted) {
        ToastUtils.showError(e.code != null
            ? ErrorMapper.getLocalizedString(context, e.code!)
            : ErrorMapper.getLocalizedString(context, 'auth_error_login_failed'));
      }
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack, operation: 'LoginLanding: unexpected');
      if (mounted) {
        ToastUtils.showError(AppLocalizations.of(context)!.unexpectedError);
      }
    } finally {
      if (mounted) {
        // AuthProvider handles its own loading state, but we ensure consistency
      }
    }
  }

  Future<void> _handleFindStore() async {
    if (!(_employeeFormKey.currentState?.validate() ?? false)) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

    try {
      final store = await authProvider.findStoreByEmail(
        _storeEmailController.text.trim(),
      );

      if (store != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmployeeLoginScreen(store: store),
          ),
        );
      } else if (mounted) {
        if (authProvider.errorMessage != null) {
          ToastUtils.showError(
              ErrorMapper.getLocalizedString(context, authProvider.errorMessage!));
        } else {
          ToastUtils.showError(AppLocalizations.of(context)!.unexpectedError);
        }
      }
    } finally {
      if (mounted) {
        // Consistency
      }
    }
  }

  void _navigateBasedOnRole(AuthProvider authProvider) {
    if (!mounted) return;

    // 1. Check if subscription is expired
    if (authProvider.isSubscriptionExpired) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteConstants.licenseExpired,
        (route) => false,
      );
      return;
    }

    // 2. Check role and navigate accordingly
    final role = authProvider.currentUser?.role;
    if (role == UserRole.owner || role == UserRole.employee) {
      Navigator.pushReplacementNamed(context, RouteConstants.ownerDashboard);
    } else {
      ToastUtils.showError(AppLocalizations.of(context)!.unexpectedError);
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DoubleBackToExitWrapper(
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg(context),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 48),
              // Header
              Text('Wallet Manager',
                  style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
              const SizedBox(height: 32),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider(context)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary.withAlpha(26),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary(context),
                  labelStyle: AppTextStyles.bodyLarge
                      .copyWith(fontWeight: FontWeight.bold),
                  labelPadding: const EdgeInsets.symmetric(vertical: 12),
                  tabs: [
                    Tab(text: l10n.owner),
                    Tab(text: l10n.employee),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOwnerTab(),
                    _buildEmployeeTab(),
                  ],
                ),
              ),

              // Footer
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOwnerTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _ownerFormKey,
        child: Column(
          children: [
            CustomTextField(
              controller: _ownerEmailController,
              labelText: l10n.email,
              prefixIcon: const Icon(Icons.email_outlined),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _ownerPasswordController,
              labelText: l10n.password,
              prefixIcon: const Icon(Icons.lock_outline),
              validator: Validators.validatePassword,
              obscureText: _obscureOwnerPassword,
              suffixIcon: IconButton(
                icon: Icon(_obscureOwnerPassword
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () => setState(
                    () => _obscureOwnerPassword = !_obscureOwnerPassword),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _showForgotPasswordBottomSheet(context),
                child: Text(
                  l10n.forgotPassword,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Selector<AuthProvider, bool>(
              selector: (_, p) => p.isLoading,
              builder: (context, isLoading, child) {
                return CustomButton(
                  text: l10n
                      .logout, // Using logout as placeholder for login if no explicit key
                  onPressed: isLoading ? null : _handleOwnerLoginWithEmail,
                  isLoading: isLoading,
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(l10n.orLabel, style: AppTextStyles.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            Selector<AuthProvider, bool>(
              selector: (_, p) => p.isLoading,
              builder: (context, isLoading, child) {
                return CustomButton(
                  text: l10n.continueWithGoogle,
                  onPressed: isLoading ? null : _handleOwnerLoginWithGoogle,
                  isLoading: isLoading,
                  type: ButtonType.outlined,
                  icon: const FaIcon(FontAwesomeIcons.google,
                      color: AppColors.primary),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTab() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _employeeFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Text(
              l10n.enterStoreEmailMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _storeEmailController,
              labelText: l10n.storeEmail,
              prefixIcon: const Icon(Icons.store_outlined),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
            Selector<AuthProvider, bool>(
              selector: (_, p) => p.isLoading,
              builder: (context, isLoading, child) {
                return CustomButton(
                  text: l10n.findStore,
                  onPressed: isLoading ? null : _handleFindStore,
                  isLoading: isLoading,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Column(
        children: [
          Text(
            l10n.noAccountYet,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary(context)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, RouteConstants.storeRegistration);
            },
            child: Text(
              l10n.createStoreNew,
              style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordBottomSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final emailController =
        TextEditingController(text: _ownerEmailController.text);
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.forgotPassword, style: AppTextStyles.h2),
              const SizedBox(height: 8),
              Text(
                l10n.forgotPasswordMessage,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: emailController,
                labelText: l10n.email,
                prefixIcon: const Icon(Icons.email_outlined),
                validator: Validators.validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              const SizedBox(height: 24),
              Selector<AuthProvider, bool>(
                selector: (_, p) => p.isLoading,
                builder: (context, isLoading, child) {
                  return CustomButton(
                    text: l10n.sendLink,
                    onPressed: isLoading
                        ? null
                        : () async {
                            if (formKey.currentState!.validate()) {
                              await _handleForgotPassword(
                                  context, emailController.text.trim());
                            }
                          },
                    isLoading: isLoading,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleForgotPassword(BuildContext context, String email) async {
    final authProvider = context.read<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    await authProvider.sendPasswordReset(email);

    if (!context.mounted) return;

    if (authProvider.errorMessage != null) {
      ToastUtils.showError(
          ErrorMapper.getLocalizedString(context, authProvider.errorMessage!));
    } else {
      Navigator.pop(context);
      ToastUtils.showSuccess(l10n.passwordResetEmailSent);
    }
  }
}
