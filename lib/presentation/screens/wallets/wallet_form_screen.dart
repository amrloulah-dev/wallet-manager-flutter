import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/number_formatter.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_dropdown.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class WalletFormScreen extends StatefulWidget {
  const WalletFormScreen({super.key});

  @override
  State<WalletFormScreen> createState() => _WalletFormScreenState();
}

class _WalletFormScreenState extends State<WalletFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  bool _isEditMode = false;
  WalletModel? _walletToEdit;
  String? _selectedWalletType;
  String? _selectedWalletStatus;

  // Map for wallet type display names
  // Map for wallet type display names
  Map<String, String> _getWalletTypeDisplayNames(BuildContext context) {
    return {
      'vodafone_cash': AppLocalizations.of(context)!.vodafoneCash,
      'instapay': AppLocalizations.of(context)!.instapay,
      'orange_cash': AppLocalizations.of(context)!.orangeCash,
      'etisalat_cash': AppLocalizations.of(context)!.etisalatCash,
      'we_pay': AppLocalizations.of(context)!.wePay,
      'other': AppLocalizations.of(context)!.other,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final wallet = ModalRoute.of(context)?.settings.arguments as WalletModel?;
      if (wallet != null) {
        _initializeEditMode(wallet);
      }
      // Clear any previous errors when the screen loads
      Provider.of<WalletProvider>(context, listen: false).clearError();
    });
  }

  void _initializeEditMode(WalletModel wallet) {
    setState(() {
      _isEditMode = true;
      _walletToEdit = wallet;
      _phoneController.text = wallet.phoneNumber;
      _notesController.text = wallet.notes ?? '';
      _selectedWalletType = wallet.walletType;
      _selectedWalletStatus = wallet.walletStatus;
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _notesController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    walletProvider.clearError();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedWalletType == null) {
      ToastUtils.showError(
          AppLocalizations.of(context)!.pleaseSelectWalletType);
      return;
    }

    if (_selectedWalletStatus == null) {
      ToastUtils.showError(
          AppLocalizations.of(context)!.pleaseSelectWalletStatus);
      return;
    }

    final userId = authProvider.currentUserId;
    if (userId == null) {
      ToastUtils.showError(AppLocalizations.of(context)!.authErrorRelogin);
      return;
    }

    bool success = false;
    if (_isEditMode) {
      // Update logic
      final data = {
        'walletType': _selectedWalletType,
        'notes': _notesController.text,
        // Wallet status and phone number are not editable in this version
      };
      success =
          await walletProvider.updateWallet(_walletToEdit!.walletId, data);
    } else {
      // Create logic
      success = await walletProvider.createWallet(
        phoneNumber: _phoneController.text,
        walletType: _selectedWalletType!,
        walletStatus: _selectedWalletStatus!,
        balance: double.tryParse(_balanceController.text) ?? 0.0,
        notes: _notesController.text,
        createdBy: userId,
      );
    }

    if (success) {
      if (!mounted) return;
      ToastUtils.showSuccess(_isEditMode
          ? AppLocalizations.of(context)!.walletUpdatedSuccessfully
          : AppLocalizations.of(context)!.walletAddedSuccessfully);
      Navigator.of(context).pop();
    }
    // Error message is displayed by the Consumer widget
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode
            ? AppLocalizations.of(context)!.editWallet
            : AppLocalizations.of(context)!.addNewWallet),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhoneNumberField(),
                const SizedBox(height: 16),
                _buildBalanceField(),
                const SizedBox(height: 16),
                _buildWalletTypeDropdown(),
                const SizedBox(height: 24),
                _buildWalletStatusDropdown(),
                if (_selectedWalletStatus != null) ...[
                  const SizedBox(height: 24),
                  _buildLimitsInfoCard(),
                ],
                const SizedBox(height: 24),
                _buildNotesField(),
                const SizedBox(height: 32),
                _buildErrorMessage(),
                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneNumberField() {
    return CustomTextField(
      controller: _phoneController,
      labelText: AppLocalizations.of(context)!.phoneNumber,
      hintText: AppLocalizations.of(context)!.phonePlaceholder,
      enabled: !_isEditMode,
      readOnly: _isEditMode,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      maxLength: 11,
      validator: Validators.validatePhoneNumber,
      prefixIcon: const Icon(Icons.phone_android),
    );
  }

  Widget _buildBalanceField() {
    return CustomTextField(
      controller: _balanceController,
      labelText: AppLocalizations.of(context)!.initialBalance,
      hintText: '0.00',
      enabled: !_isEditMode,
      readOnly: _isEditMode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
      ],
      validator: (val) => Validators.validateAmount(val, minAmount: -1),
      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
    );
  }

  Widget _buildWalletTypeDropdown() {
    final walletTypes = _getWalletTypeDisplayNames(context);
    return CustomDropdown<String>(
      value: _selectedWalletType,
      labelText: AppLocalizations.of(context)!.walletType,
      prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
          color: AppColors.primary),
      hint: AppLocalizations.of(context)!.selectWalletType,
      items: walletTypes.keys.map((String key) {
        return DropdownMenuItem<String>(
          value: key,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha((0.05 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withAlpha((0.3 * 255).round()),
                  width: 1,
                ),
              ),
              child: Text(
                walletTypes[key]!,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        );
      }).toList(),
      selectedItemBuilder: (BuildContext context) {
        return walletTypes.keys.map((String key) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              walletTypes[key]!,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          );
        }).toList();
      },
      onChanged: (value) {
        setState(() {
          _selectedWalletType = value;
        });
      },
      validator: (value) => value == null
          ? AppLocalizations.of(context)!.walletTypeRequired
          : null,
      fillColor: AppColors.primary.withAlpha((0.05 * 255).round()),
    );
  }

  Widget _buildWalletStatusDropdown() {
    final statusDisplayNames = {
      'new': AppLocalizations.of(context)!.newStatus,
      'old': AppLocalizations.of(context)!.oldStatus,
      'registered_store': AppLocalizations.of(context)!.registeredStore,
    };

    return CustomDropdown<String>(
      value: _selectedWalletStatus,
      labelText: AppLocalizations.of(context)!.walletStatus,
      prefixIcon:
          const Icon(Icons.verified_user_outlined, color: AppColors.primary),
      hint: AppLocalizations.of(context)!.pleaseSelectWalletStatus,
      // 1. استخدام keys.map لتكرار نفس التصميم
      items: statusDisplayNames.keys.map((String key) {
        return DropdownMenuItem<String>(
          value: key,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha((0.05 * 255).round()),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primary.withAlpha((0.3 * 255).round()),
                  width: 1,
                ),
              ),
              child: Text(
                statusDisplayNames[key]!,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black, // لون النص داخل القائمة المنسدلة
                ),
              ),
            ),
          ),
        );
      }).toList(),
      // 2. إضافة selectedItemBuilder لضبط شكل العنصر المختار وهو مغلق
      selectedItemBuilder: (BuildContext context) {
        return statusDisplayNames.keys.map((String key) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              statusDisplayNames[key]!,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context), // لون النص وهو مختار
              ),
            ),
          );
        }).toList();
      },
      // الحفاظ على منطق التعديل كما هو
      onChanged: _isEditMode
          ? null
          : (value) {
              setState(() {
                _selectedWalletStatus = value;
              });
            },
      validator: (value) => value == null
          ? AppLocalizations.of(context)!.pleaseSelectWalletStatus
          : null,
      fillColor: AppColors.primary.withAlpha((0.05 * 255).round()),
    );
  }

  Widget _buildLimitsInfoCard() {
    final dailyLimit = _getDailyLimit();
    final monthlyLimit = _getMonthlyLimit();

    return Card(
      color: AppColors.primary.withAlpha((0.05 * 255).round()),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: AppColors.primary.withAlpha((0.2 * 255).round())),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.walletLimits,
                  style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildLimitRow(AppLocalizations.of(context)!.dailyLimit,
                NumberFormatter.formatAmount(dailyLimit)),
            const SizedBox(height: 8),
            _buildLimitRow(AppLocalizations.of(context)!.monthlyLimit,
                NumberFormatter.formatAmount(monthlyLimit)),
          ],
        ),
      ),
    );
  }

  double _getDailyLimit() {
    if (_selectedWalletType == 'instapay') {
      return AppConstants.instapayTransactionLimit;
    }
    if (_selectedWalletStatus == 'registered_store') {
      return AppConstants.registeredStoreTransactionLimit;
    }
    return _selectedWalletStatus == 'new'
        ? AppConstants.newWalletTransactionLimit
        : AppConstants.oldWalletTransactionLimit;
  }

  double _getMonthlyLimit() {
    if (_selectedWalletType == 'instapay') {
      return AppConstants.instapayMonthlyLimit;
    }
    if (_selectedWalletStatus == 'registered_store') {
      return AppConstants.registeredStoreMonthlyLimit;
    }
    return _selectedWalletStatus == 'new'
        ? AppConstants.newWalletMonthlyLimit
        : AppConstants.oldWalletMonthlyLimit;
  }

  Widget _buildLimitRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium),
        Text(value,
            style:
                AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
      ],
    );
  }

  Widget _buildNotesField() {
    return CustomTextField(
      controller: _notesController,
      labelText: AppLocalizations.of(context)!.notesOptional,
      hintText: AppLocalizations.of(context)!.notesPlaceholder,
      maxLines: 3,
      maxLength: 200,
      validator: (value) => Validators.validateNotes(value, maxLength: 200),
      prefixIcon: const Icon(Icons.note_alt_outlined),
    );
  }

  Widget _buildSaveButton() {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        return CustomButton(
          text: _isEditMode
              ? AppLocalizations.of(context)!.saveChanges
              : AppLocalizations.of(context)!.addWalletAction,
          onPressed: _handleSubmit,
          isLoading: provider.isCreating || provider.isUpdating,
        );
      },
    );
  }

  Widget _buildErrorMessage() {
    return Consumer<WalletProvider>(
      builder: (context, provider, child) {
        if (provider.hasError && provider.errorMessage != null) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.errorMessage!,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
