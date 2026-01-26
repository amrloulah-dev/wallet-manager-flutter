import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/providers/auth_provider.dart';

class LoginLandingScreen extends StatefulWidget {
  const LoginLandingScreen({super.key});

  @override
  State<LoginLandingScreen> createState() => _LoginLandingScreenState();
}

class _LoginLandingScreenState extends State<LoginLandingScreen> {
  Future<void> _handleOwnerLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.isLoading) return;

    final success = await authProvider.loginWithGoogleOrNull();

    if (success && mounted) {
      // Navigation is handled by the consumer/listener in the build method or parent
      // But typically we navigate manually or rely on stream.
      // In StoreRegistrationScreen, navigation was done manually in addPostFrameCallback
      // We will rely on Consumer in build to navigate if authenticated.
    } else if (mounted) {
      // loginWithGoogleOrNull handles toast for errors usually, or we can show one here.
      if (authProvider.errorMessage != null) {
        ToastUtils.showError(authProvider.errorMessage!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          // Navigation listener
          if (authProvider.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // Check role and navigate accordingly
              final userRole = authProvider.currentUser?.role ?? '';
              if (userRole == 'owner') {
                Navigator.pushReplacementNamed(
                    context, RouteConstants.ownerDashboard);
              } else if (userRole == 'employee') {
                Navigator.pushReplacementNamed(
                    context, RouteConstants.employeeDashboard);
              } else {
                // Store registration or error? If they logged in but no store, maybe register?
                // But this is "Login Landing".
                // Logic from StoreRegistrationScreen suggested going to dashboard if authenticated.
                Navigator.pushReplacementNamed(
                    context, RouteConstants.storeRegistration);
              }
            });
            return const Center(child: CircularProgressIndicator());
          }

          return SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                children: [
                  // Header: Top 1/3
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wallet,
                            size: 100, color: AppColors.primary),
                        const SizedBox(height: 24),
                        Text(
                          'Wallet Manager',
                          style: AppTextStyles.h1.copyWith(fontSize: 32),
                        ),
                      ],
                    ),
                  ),

                  // Body: Actions
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomButton(
                          text: 'تسجيل الدخول كمالك',
                          onPressed: _handleOwnerLogin,
                          isLoading: authProvider.isLoading,
                          icon: const FaIcon(FontAwesomeIcons.google,
                              color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, RouteConstants.employeeLogin);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: AppColors.primary, width: 2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('تسجيل الدخول كموظف',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary, // Text color
                                )),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Footer
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'ليس لديك حساب؟',
                          style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary(context)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(
                                context, RouteConstants.storeRegistration);
                          },
                          child: Text(
                            'إنشاء متجر جديد',
                            style: AppTextStyles.h3
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
