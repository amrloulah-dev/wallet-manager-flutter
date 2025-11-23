import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../providers/wallet_provider.dart';
import '../../../data/models/wallet_model.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/custom_button.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class AddBalanceScreen extends StatefulWidget {
  const AddBalanceScreen({super.key});

  @override
  State<AddBalanceScreen> createState() => _AddBalanceScreenState();
}

class _AddBalanceScreenState extends State<AddBalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  WalletModel? _selectedWallet;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_selectedWallet == null) {
      ToastUtils.showError(
          AppLocalizations.of(context)!.pleaseSelectWalletFirst);
      return;
    }

    setState(() => _isSubmitting = true);

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final walletProvider = context.read<WalletProvider>();
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUserId;

    if (currentUserId == null) {
      ToastUtils.showError(AppLocalizations.of(context)!.userNotAuthenticated);
      setState(() => _isSubmitting = false);
      return;
    }

    final success = await walletProvider.addBalanceToWallet(
      _selectedWallet!.walletId,
      amount,
      currentUserId,
    );

    if (mounted) {
      if (success) {
        ToastUtils.showSuccess(
            AppLocalizations.of(context)!.balanceAddedSuccessfully);
        Navigator.pop(context);
      } else {
        ToastUtils.showError(walletProvider.errorMessage ??
            AppLocalizations.of(context)!.failedToAddBalance);
      }
    }

    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.addBalanceToWallet),
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
                _buildWalletSelection(),
                const SizedBox(height: 24),
                if (_selectedWallet != null) ...[
                  _buildWalletInfoCard(),
                  const SizedBox(height: 24),
                  _buildAmountField(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletSelection() {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        if (walletProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (walletProvider.wallets.isEmpty) {
          return Text(AppLocalizations.of(context)!.noWalletsAvailable);
        }
        return DropdownButtonFormField<WalletModel>(
          value: _selectedWallet,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.selectWallet,
            prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: AppColors.primary.withAlpha((0.05 * 255).round()),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
          hint: Text(AppLocalizations.of(context)!.selectWalletToAddBalance),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppColors.primary, size: 28),
          style: AppTextStyles.bodyLarge,
          isExpanded: true,
          dropdownColor: Colors.white,
          items: walletProvider.wallets.map((WalletModel wallet) {
            return DropdownMenuItem<WalletModel>(
              value: wallet,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withAlpha((0.3 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${wallet.walletTypeDisplayName} - ${NumberFormatter.formatPhoneNumber(wallet.phoneNumber)}',
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
            return walletProvider.wallets.map((WalletModel wallet) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${wallet.walletTypeDisplayName} - ${NumberFormatter.formatPhoneNumber(wallet.phoneNumber)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              );
            }).toList();
          },
          onChanged: (wallet) {
            setState(() {
              _selectedWallet = wallet;
            });
          },
          validator: (value) => value == null
              ? AppLocalizations.of(context)!.pleaseSelectWallet
              : null,
        );
      },
    );
  }

  Widget _buildWalletInfoCard() {
    if (_selectedWallet == null) return const SizedBox.shrink();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.selectedWalletDetails,
                style: AppTextStyles.h3),
            const Divider(height: 20),
            _buildInfoRow(AppLocalizations.of(context)!.currentBalanceLabel,
                NumberFormatter.formatAmount(_selectedWallet!.balance)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyLarge),
        Text(value,
            style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
      ],
    );
  }

  Widget _buildAmountField() {
    return CustomTextField(
      controller: _amountController,
      labelText: AppLocalizations.of(context)!.amountToAdd,
      hintText: '0.00',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
      ],
      validator: (val) => Validators.validateAmount(val, minAmount: 1),
      prefixIcon: const Icon(Icons.attach_money_outlined),
    );
  }

  Widget _buildSubmitButton() {
    return CustomButton(
      text: AppLocalizations.of(context)!.addBalanceAction,
      onPressed: _handleSubmit,
      isLoading: _isSubmitting,
      icon: const Icon(Icons.add),
    );
  }
}
