import 'package:walletmanager/core/errors/app_exceptions.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/errors/error_severity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/constants/route_constants.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/password_hasher.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/store_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/employee_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_dropdown.dart';
import 'package:walletmanager/presentation/widgets/common/loading_indicator.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:walletmanager/presentation/widgets/common/double_back_to_exit_wrapper.dart';

class EmployeeLoginScreen extends StatefulWidget {
  final StoreModel store;
  const EmployeeLoginScreen({super.key, required this.store});

  @override
  State<EmployeeLoginScreen> createState() => _EmployeeLoginScreenState();
}

class _EmployeeLoginScreenState extends State<EmployeeLoginScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _storePasswordController = TextEditingController();
  final _pinController = TextEditingController();

  // State
  UserModel? _selectedEmployee;
  bool _isLoading = false;
  bool _obscureStorePassword = true;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    // Fetch employees for this store immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().setStoreId(widget.store.storeId);
    });
  }

  @override
  void dispose() {
    _storePasswordController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() => _isLoading = loading);
    }
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;

    if (_selectedEmployee == null) {
      ToastUtils.showError(l10n.pleaseSelectEmployee);
      return;
    }

    _setLoading(true);
    final authProvider = context.read<AuthProvider>();

    try {
      // Check if store subscription is expired before attempting login
      // We must abort login and show toast according to Phase 5 spec
      if (widget.store.subscription.isExpiredAt(DateTime.now())) {
        ToastUtils.showError(l10n.subscriptionExpired);
        return;
      }

      // 1. Verify Store Password
      if (!await PasswordHasher.verifyPassword(
          _storePasswordController.text, widget.store.storePassword)) {
        throw AuthException(l10n.storePasswordInvalid);
      }

      // 2. Verify Employee PIN
      if (!await PasswordHasher.verifyPassword(
          _pinController.text, _selectedEmployee!.pin!)) {
        // Double check if legacy plain text match works (optional safety)
        if (_selectedEmployee!.pin != _pinController.text) {
          throw AuthException(l10n.pinInvalid);
        }
      }

      // 3. Login
      final success = await authProvider.loginAsEmployee(
          _selectedEmployee!, widget.store,
          rawPin: _pinController.text);

      if (success) {
        if (!mounted) return;

        if (authProvider.isSubscriptionExpired) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteConstants.licenseExpired,
            (route) => false,
          );
          return;
        }

        Navigator.pushReplacementNamed(context, RouteConstants.mainDashboard);
        ToastUtils.showSuccess(
            '${l10n.welcome} ${_selectedEmployee!.fullName}');
      } else {
        if (mounted && authProvider.errorMessage != null) {
          ToastUtils.showError(authProvider.errorMessage!);
        }
      }
    } catch (e, stack) {
      if (mounted) {
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          severity: ErrorSeverity.critical,
          operation: 'EmployeeLogin._handleLogin',
        );
        ToastUtils.showError(l10n.unexpectedError);
      }
    } finally {
      _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DoubleBackToExitWrapper(
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBg(context),
        appBar: AppBar(
          title: Text(l10n.employeeLogin),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: _isLoading
            ? LoadingIndicator(message: l10n.loggingIn)
            : SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Store Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primary.withAlpha(77)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.store_rounded,
                                    size: 48, color: AppColors.primary),
                                const SizedBox(height: 12),
                                Text(
                                  widget.store.storeName,
                                  style: AppTextStyles.h2
                                      .copyWith(color: AppColors.primary),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.employeeLoginSubtitle,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.textSecondary(context)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // 1. Store Password
                          CustomTextField(
                            controller: _storePasswordController,
                            labelText: l10n.storePassword,
                            hintText: l10n.enterStorePassword,
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureStorePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () => setState(() =>
                                  _obscureStorePassword =
                                      !_obscureStorePassword),
                            ),
                            obscureText: _obscureStorePassword,
                            keyboardType: TextInputType.text,
                            // No strict validation on length here to allow flexibility, just not empty
                            validator: (val) => val == null || val.isEmpty
                                ? l10n.requiredField
                                : null,
                          ),
                          const SizedBox(height: 20),

                          // 2. Select Employee
                          Selector<
                              EmployeeProvider,
                              ({
                                List<UserModel> employees,
                                bool isLoading,
                                bool hasError,
                                String? errorMessage
                              })>(
                            selector: (_, p) => (
                              employees: p.activeEmployees,
                              isLoading: p.isLoading,
                              hasError: p.hasError,
                              errorMessage: p.errorMessage
                            ),
                            builder: (context, data, child) {
                              if (data.isLoading) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              } else if (data.hasError) {
                                return Center(
                                    child: Text(data.errorMessage ?? l10n.error,
                                        style: const TextStyle(
                                            color: Colors.red)));
                              } else {
                                return CustomDropdown<UserModel>(
                                  labelText: l10n.selectEmployee,
                                  hint: l10n.selectEmployeeHint,
                                  value: _selectedEmployee,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  fillColor: AppColors.primary.withAlpha(13),
                                  itemsList: data.employees,
                                  itemLabelBuilder: (UserModel employee) =>
                                      employee.fullName,
                                  onChanged: (val) {
                                    setState(() => _selectedEmployee = val);
                                  },
                                  validator: (val) => val == null
                                      ? l10n.pleaseSelectEmployee
                                      : null,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // 3. Employee PIN
                          CustomTextField(
                            controller: _pinController,
                            labelText: l10n.pinLabel,
                            hintText: '****',
                            prefixIcon: const Icon(Icons.pin_outlined),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () =>
                                  setState(() => _obscurePin = !_obscurePin),
                            ),
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return l10n.requiredField;
                              }
                              if (val.length != 6) return l10n.pinMustBe4Digits;
                              return null;
                            },
                          ),

                          const SizedBox(height: 32),

                          CustomButton(
                            text: l10n.loginAction,
                            onPressed: _handleLogin,
                            icon: const Icon(Icons.login),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
