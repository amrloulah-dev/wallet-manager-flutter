import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/presentation/widgets/common/custom_dropdown.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';

class TransactionOverlayScreen extends StatelessWidget {
  const TransactionOverlayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine language from local storage (defaulting to Arabic if not English)
    final isAr = LocalStorageService.instance.languageCode != 'en';

    return ChangeNotifierProvider(
      create: (_) => OverlayProvider(),
      // Wrap in a MaterialApp to provide Theme and Localization context to the overlay,
      // as overlays are detached from the main app's widget tree.
      child: Theme(
        data: ThemeData.light(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.light(), // Enforce explicitly light theme
          themeMode: ThemeMode.light,
          builder: (context, child) {
            return Directionality(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              child: Theme(
                data: ThemeData.light(),
                child: child!,
              ),
            );
          },
          home: const _OverlayContent(),
        ),
      ),
    );
  }
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent({Key? key}) : super(key: key);

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  late OverlayProvider _provider;
  late FocusNode _commissionFocusNode;
  StreamSubscription? _overlaySubscription;

  @override
  void initState() {
    super.initState();
    _commissionFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = Provider.of<OverlayProvider>(context, listen: false);

      // -----------------------------------------------------------------------
      // STREAM LISTENER — Parse every overlay event through ingestNewEvent().
      // This guarantees a full state reset before applying new SMS data,
      // even when the Flutter engine is kept warm between activations.
      // -----------------------------------------------------------------------
      _overlaySubscription =
          FlutterOverlayWindow.overlayListener.listen((event) {

        if (event != null && event is Map) {
          _provider.ingestNewEvent(event);
        } else {

        }
      });

      // Request focus after a short delay so the Android WindowManager has
      // fully attached the overlay window and granted it IME focus.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _commissionFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _commissionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _provider = Provider.of<OverlayProvider>(context);
    final theme = ThemeData.light(); // Explicit Light Mode
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Error Snackbar
    if (_provider.errorMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_provider.errorMessage!,
                style:
                    textTheme.bodyMedium?.copyWith(color: colorScheme.onError)),
            backgroundColor: colorScheme.error,
          ),
        );
      });
    }

    final isAr = LocalStorageService.instance.languageCode != 'en';

    // Localized Strings
    final txtTitle = isAr ? 'معاملة جديدة' : 'New Transaction';
    final txtAmount = isAr ? 'المبلغ' : 'Amount';
    final txtSender = isAr ? 'الراسل' : 'Sender';
    final txtWallet = isAr ? 'اختر المحفظة' : 'Select Wallet';
    final txtCommission = isAr ? 'العمولة' : 'Commission (EGP)';
    final txtSave = isAr ? 'تأكيد وحفظ' : 'Confirm & Save';
    final txtUnknown = isAr ? 'غير معروف' : 'Unknown';

    return Theme(
      data: ThemeData.light(),
      child: Scaffold(
        backgroundColor:
            const Color(0x00000000), // Transparent overlay background
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors
                  .white, // dynamically adapt to dark/light -> Explicit light mode
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderWidget(
                      title: txtTitle,
                      onClose: _provider.close,
                    ),
                    Divider(height: 24, color: Colors.grey.shade300),
                    if (!_provider.isLoading ||
                        _provider.availableWallets.isNotEmpty) ...[
                      _HeroAmountWidget(
                        txtAmount: txtAmount,
                        amount: _provider.amount.toString(),
                        type: _provider.type,
                      ),
                      const SizedBox(height: 16),
                      _SenderDisplayWidget(
                        txtSender: txtSender,
                        sender: _provider.sender,
                      ),
                      const SizedBox(height: 16),
                      _WalletDropdownWidget(
                        provider: _provider,
                        txtWallet: txtWallet,
                        txtUnknown: txtUnknown,
                      ),
                      const SizedBox(height: 16),
                      _CommissionFieldWidget(
                        provider: _provider,
                        txtCommission: txtCommission,
                        focusNode: _commissionFocusNode,
                      ),
                      const SizedBox(height: 24),
                      CustomButton(
                        text: txtSave,
                        isLoading: _provider.isLoading,
                        onPressed: _provider.submitTransaction,
                        fullWidth: true,
                      ),
                    ] else
                      const Center(
                          child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary))),
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

// -----------------------------------------------------------------------------
// Small Reusable Widgets
// -----------------------------------------------------------------------------

/// Header for the Overlay containing title and close button
class _HeaderWidget extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _HeaderWidget({
    required this.title,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.black54),
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// Hero section displaying the transaction amount
class _HeroAmountWidget extends StatelessWidget {
  final String txtAmount;
  final String amount;
  final String type;

  const _HeroAmountWidget({
    required this.txtAmount,
    required this.amount,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    // Use specific colors: green for credit, red for debit
    final amountColor = (type == 'credit') ? Colors.green : Colors.red;

    return Column(
      children: [
        Text(
          txtAmount,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$amount EGP',
          textAlign: TextAlign.center,
          textDirection:
              TextDirection.ltr, // Keep numeric correctly formatted in LTR
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}

/// Read-only display for the Sender information.
class _SenderDisplayWidget extends StatelessWidget {
  final String txtSender;
  final String sender;

  const _SenderDisplayWidget({
    required this.txtSender,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    // Replace CustomTextField with a visual read-only Container.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // light grey background
        borderRadius: BorderRadius.circular(12), // rounded border
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline,
              color: Colors.black54), // person icon
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sender, // displaying parsed phone number/sender
              style: const TextStyle(
                color: Colors.black87, // black/dark grey text
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown for selecting a wallet
class _WalletDropdownWidget extends StatelessWidget {
  final OverlayProvider provider;
  final String txtWallet;
  final String txtUnknown;

  const _WalletDropdownWidget({
    required this.provider,
    required this.txtWallet,
    required this.txtUnknown,
  });

  @override
  Widget build(BuildContext context) {
    return CustomDropdown<String>(
      value: provider.selectedWalletId,
      labelText: txtWallet,
      prefixIcon: const Icon(
        Icons.account_balance_wallet,
      ),
      itemsList: provider.availableWallets
          .map((wallet) => wallet['id'].toString())
          .toList(),
      itemLabelBuilder: (String id) {
        final wallet = provider.availableWallets.firstWhere(
          (w) => w['id'] == id,
          orElse: () => {'name': txtUnknown},
        );
        return wallet['name'] ?? txtUnknown;
      },
      onChanged: provider.setSelectedWallet,
    );
  }
}

/// Text field for entering commission with focus management
class _CommissionFieldWidget extends StatelessWidget {
  final OverlayProvider provider;
  final String txtCommission;
  final FocusNode focusNode;

  const _CommissionFieldWidget({
    required this.provider,
    required this.txtCommission,
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      labelText: txtCommission,
      prefixIcon: const Icon(Icons
          .attach_money), // Use prefixIcon instead of suffixIcon for RTL right alignment
      onChanged: provider.setCommission,
    );
  }
}
