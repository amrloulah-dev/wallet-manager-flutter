import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/subscription_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/enums/subscription_enums.dart';

class PaymentModalScreen extends StatefulWidget {
  final SubscriptionPlan planId; // ENUM refactor

  const PaymentModalScreen({super.key, required this.planId});

  static void show(BuildContext context, SubscriptionPlan planId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PaymentModalScreen(planId: planId),
    );
  }

  @override
  State<PaymentModalScreen> createState() => _PaymentModalScreenState();
}

class _PaymentModalScreenState extends State<PaymentModalScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedMethod = 'vodafone_cash';
  final _receiptController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _receiptController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final subProvider = context.read<SubscriptionProvider>();
      await subProvider.submitSubscriptionRequest(
        planId: widget.planId,
        paymentMethod: _selectedMethod,
        receiptNumber: _receiptController.text.trim(),
      );

      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      await authProvider.tryAutoLogin();

      if (!mounted) return;

      final loc = AppLocalizations.of(context)!;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.subscriptionRequestSent)),
      );
    } catch (e) {
      if (mounted) {
        final loc = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.errorOccurred} $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final planName = widget.planId == SubscriptionPlan.lifetime
        ? loc.lifetimePlan
        : loc.proYearlyTitle;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  loc.paymentDetails,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.selectedPlan(planName),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(loc.paymentMethod,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMethodSelector('vodafone_cash', loc.vodafoneCash,
                          Icons.phone_android),
                      const SizedBox(width: 12),
                      _buildMethodSelector(
                          'instapay', loc.instaPay, Icons.account_balance),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedMethod == 'vodafone_cash'
                            ? loc.transferToNumber
                            : loc.transferToAccount,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _receiptController,
                  decoration: InputDecoration(
                    labelText: loc.receiptNumber,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.receipt),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return loc.fieldRequired;
                    }
                    return Validators.validatePhoneNumber(value.trim());
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          loc.confirmPayment,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodSelector(String value, String label, IconData icon) {
    final isSelected = _selectedMethod == value;
    final color =
        isSelected ? Theme.of(context).primaryColor : Colors.grey[400];

    return InkWell(
      onTap: () => setState(() => _selectedMethod = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: color!, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? color.withAlpha(26) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
