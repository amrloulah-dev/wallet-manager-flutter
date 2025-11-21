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
  final Map<String, String> _walletTypeDisplayNames = {
    'vodafone_cash': 'فودافون كاش',
    'instapay': 'إنستاباي',
    'orange_cash': 'أورانج كاش',
    'etisalat_cash': 'اتصالات كاش',
    'we_pay': 'WE Pay',
    'other': 'أخرى',
  };

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
      ToastUtils.showError('يرجى اختيار نوع المحفظة');
      return;
    }

    if (_selectedWalletStatus == null) {
      ToastUtils.showError('يرجى اختيار حالة المحفظة');
      return;
    }

    final userId = authProvider.currentUserId;
    if (userId == null) {
      ToastUtils.showError('خطأ في المصادقة، يرجى تسجيل الدخول مرة أخرى');
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
      success = await walletProvider.updateWallet(_walletToEdit!.walletId, data);
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
      ToastUtils.showSuccess(_isEditMode
              ? 'تم تعديل المحفظة بنجاح'
              : 'تم إضافة المحفظة بنجاح');
      if (!mounted) return;
      Navigator.of(context).pop();
    }
    // Error message is displayed by the Consumer widget
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'تعديل المحفظة' : 'إضافة محفظة جديدة'),
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
                _buildWalletStatusRadios(),
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
      labelText: 'رقم الموبايل',
      hintText: '01xxxxxxxxx',
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
      labelText: 'الرصيد المبدئي',
      hintText: '0.00',
      enabled: !_isEditMode,
      readOnly: _isEditMode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
      validator: (val) => Validators.validateAmount(val, minAmount: -1),
      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
    );
  }

  Widget _buildWalletTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedWalletType,
      decoration: InputDecoration(
        labelText: 'نوع المحفظة',
        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppColors.primary.withAlpha((0.05 * 255).round()),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      hint: const Text('اختر نوع المحفظة'),
      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary, size: 28),
      style: AppTextStyles.bodyLarge,
      dropdownColor: Colors.white,
      isExpanded: true,
      itemHeight: null,
      items: _walletTypeDisplayNames.keys.map((String key) {
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
                _walletTypeDisplayNames[key]!,
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
        return _walletTypeDisplayNames.keys.map((String key) {
          return Align(
            alignment: Alignment.centerRight,
            child: Text(
              _walletTypeDisplayNames[key]!,
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
      validator: (value) => value == null ? 'نوع المحفظة مطلوب' : null,
    );
  }

  Widget _buildWalletStatusRadios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('حالة المحفظة', style: AppTextStyles.labelMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('جديدة'),
                value: 'new',
                groupValue: _selectedWalletStatus,
                onChanged: _isEditMode
                    ? null
                    : (value) => setState(() => _selectedWalletStatus = value),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('قديمة'),
                value: 'old',
                groupValue: _selectedWalletStatus,
                onChanged: _isEditMode
                    ? null
                    : (value) => setState(() => _selectedWalletStatus = value),
              ),
            ),
          ],
        ),
      ],
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
        side: BorderSide(color: AppColors.primary.withAlpha((0.2 * 255).round())),
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
                  'حدود المحفظة',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildLimitRow('الحد اليومي (إرسال/استقبال)',
                NumberFormatter.formatAmount(dailyLimit)),
            const SizedBox(height: 8),
            _buildLimitRow('الحد الشهري (إرسال/استقبال)',
                NumberFormatter.formatAmount(monthlyLimit)),
          ],
        ),
      ),
    );
  }

  double _getDailyLimit() {
    if (_selectedWalletType == 'instapay') {
      return AppConstants.instapayDailyLimit;
    }
    return _selectedWalletStatus == 'new'
        ? AppConstants.newWalletDailyLimit
        : AppConstants.oldWalletDailyLimit;
  }

  double _getMonthlyLimit() {
    if (_selectedWalletType == 'instapay') {
      return AppConstants.instapayMonthlyLimit;
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
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary)),
      ],
    );
  }

  Widget _buildNotesField() {
    return CustomTextField(
      controller: _notesController,
      labelText: 'ملاحظات (اختياري)',
      hintText: 'أي تفاصيل إضافية عن المحفظة',
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
          text: _isEditMode ? 'حفظ التعديلات' : 'إضافة المحفظة',
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
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
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
