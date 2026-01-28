import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/core/utils/validators.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import 'package:walletmanager/presentation/widgets/common/double_back_to_exit_wrapper.dart';
import 'employee_login_screen.dart';

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

    final success = await authProvider.loginOwnerWithEmail(
      _ownerEmailController.text.trim(),
      _ownerPasswordController.text,
    );

    if (success && mounted) {
      _navigateBasedOnRole(authProvider);
    } else if (mounted && authProvider.errorMessage != null) {
      ToastUtils.showError(authProvider.errorMessage!);
    }
  }

  Future<void> _handleFindStore() async {
    if (!(_employeeFormKey.currentState?.validate() ?? false)) return;

    final authProvider = context.read<AuthProvider>();
    if (authProvider.isLoading) return;

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
    } else if (mounted && authProvider.errorMessage != null) {
      ToastUtils.showError(authProvider.errorMessage!);
    }
  }

  void _navigateBasedOnRole(AuthProvider authProvider) {
    // Check role and navigate accordingly
    final userRole = authProvider.currentUser?.role ?? '';
    if (userRole == 'owner') {
      Navigator.pushReplacementNamed(context, RouteConstants.ownerDashboard);
    } else if (userRole == 'employee') {
      Navigator.pushReplacementNamed(context, RouteConstants.employeeDashboard);
    } else {
      ToastUtils.showError('Role unknown');
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
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
                    color: AppColors.primary.withOpacity(0.1),
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
                  tabs: const [
                    Tab(text: 'المالك'),
                    Tab(text: 'موظف'),
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
    final authProvider = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _ownerFormKey,
        child: Column(
          children: [
            CustomTextField(
              controller: _ownerEmailController,
              labelText: 'البريد الإلكتروني',
              prefixIcon: const Icon(Icons.email_outlined),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _ownerPasswordController,
              labelText: 'كلمة المرور',
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
                onPressed: () {
                  // TODO: Implement forgot password
                  ToastUtils.showInfo('قريباً');
                },
                child: Text(
                  'نسيت كلمة المرور؟',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary(context)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomButton(
              text: 'تسجيل الدخول',
              onPressed:
                  authProvider.isLoading ? null : _handleOwnerLoginWithEmail,
              isLoading: authProvider.isLoading,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('أو', style: AppTextStyles.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'المتابعة باستخدام Google',
              onPressed:
                  authProvider.isLoading ? null : _handleOwnerLoginWithGoogle,
              isLoading: authProvider
                  .isLoading, // Or use a separate loading state if needed
              type: ButtonType.outlined,
              icon: const FaIcon(FontAwesomeIcons.google,
                  color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTab() {
    final authProvider = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _employeeFormKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Text(
              'أدخل البريد الإلكتروني للمتجر لتسجيل الدخول كموظف',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary(context)),
            ),
            const SizedBox(height: 32),
            CustomTextField(
              controller: _storeEmailController,
              labelText: 'بريد المتجر الإلكتروني',
              prefixIcon: const Icon(Icons.store_outlined),
              validator: Validators.validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'البحث عن المتجر',
              onPressed: authProvider.isLoading ? null : _handleFindStore,
              isLoading: authProvider.isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24, top: 16),
      child: Column(
        children: [
          Text(
            'ليس لديك حساب؟',
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary(context)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, RouteConstants.storeRegistration);
            },
            child: Text(
              'إنشاء متجر جديد',
              style: AppTextStyles.h3.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
