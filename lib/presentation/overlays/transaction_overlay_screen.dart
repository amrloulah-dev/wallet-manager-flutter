import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/presentation/widgets/common/custom_dropdown.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class TransactionOverlayScreen extends StatelessWidget {
  static final ThemeData _cachedLightTheme = ThemeData.light();

  const TransactionOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine language from local storage
    final languageCode = LocalStorageService.instance.languageCode ?? 'ar';

    return ChangeNotifierProvider(
      create: (_) => OverlayProvider(),
      child: Theme(
        data: _cachedLightTheme,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _cachedLightTheme,
          themeMode: ThemeMode.light,
          locale: Locale(languageCode),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const _OverlayContent(),
        ),
      ),
    );
  }
}

class _OverlayContent extends StatefulWidget {
  const _OverlayContent();

  @override
  State<_OverlayContent> createState() => _OverlayContentState();
}

class _OverlayContentState extends State<_OverlayContent> {
  late OverlayProvider _provider;
  late FocusNode _commissionFocusNode;
  StreamSubscription? _overlaySubscription;
  Timer? _focusTimer;

  @override
  void initState() {
    super.initState();
    _commissionFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = context.read<OverlayProvider>();

      _overlaySubscription =
          FlutterOverlayWindow.overlayListener.listen((event) {
        if (event != null && event is Map) {
          _provider.ingestNewEvent(event);
        }
      }, onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ [OVERLAY] overlayListener error: $error');
        }
      });

      _focusTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          _commissionFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _focusTimer?.cancel();
    _commissionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = TransactionOverlayScreen._cachedLightTheme;
    final l10n = AppLocalizations.of(context)!;

    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(38),
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
                      title: l10n.newTransaction,
                      onClose: () => context.read<OverlayProvider>().close(),
                    ),
                    Divider(height: 24, color: Colors.grey.shade300),
                    // Listen for errors
                    const _ErrorListener(),
                    Selector<OverlayProvider, bool>(
                      selector: (_, p) =>
                          p.isLoading && p.availableWallets.isEmpty,
                      builder: (context, isLoadingInitial, _) {
                        if (isLoadingInitial) {
                          return const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: CircularProgressIndicator(
                                      color: AppColors.primary)));
                        }

                        return Column(
                          children: [
                            Selector<OverlayProvider,
                                ({double amount, String type})>(
                              selector: (_, p) =>
                                  (amount: p.amount, type: p.type),
                              builder: (context, data, _) => _HeroAmountWidget(
                                txtAmount: l10n.amount,
                                amount: data.amount,
                                type: data.type,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Selector<OverlayProvider, String>(
                              selector: (_, p) => p.sender,
                              builder: (context, sender, _) =>
                                  _SenderDisplayWidget(
                                txtSender: l10n.send,
                                sender: sender,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const _WalletDropdownWidget(),
                            const SizedBox(height: 16),
                            _CommissionFieldWidget(
                              focusNode: _commissionFocusNode,
                            ),
                            const SizedBox(height: 24),
                            Selector<OverlayProvider, bool>(
                              selector: (_, p) => p.isLoading,
                              builder: (context, isLoading, _) => CustomButton(
                                text: l10n.confirmPayment,
                                isLoading: isLoading,
                                onPressed: () => context
                                    .read<OverlayProvider>()
                                    .submitTransaction(),
                                fullWidth: true,
                              ),
                            ),
                          ],
                        );
                      },
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

class _ErrorListener extends StatelessWidget {
  const _ErrorListener();

  @override
  Widget build(BuildContext context) {
    return Consumer<OverlayProvider>(
      builder: (context, provider, child) {
        if (provider.errorMessage != null) {
          final l10n = AppLocalizations.of(context)!;
          final theme = Theme.of(context);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final displayError = ErrorMapper.getLocalizedString(context, provider.errorMessage!);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(displayError,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onError)),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          });
        }
        return const SizedBox.shrink();
      },
    );
  }
}

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

class _HeroAmountWidget extends StatelessWidget {
  final String txtAmount;
  final double amount;
  final String type;

  const _HeroAmountWidget({
    required this.txtAmount,
    required this.amount,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
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
          NumberFormatter.formatAmount(amount, showCurrency: true),
          textAlign: TextAlign.center,
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

class _SenderDisplayWidget extends StatelessWidget {
  final String txtSender;
  final String sender;

  const _SenderDisplayWidget({
    required this.txtSender,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sender,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletDropdownWidget extends StatelessWidget {
  const _WalletDropdownWidget();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Selector<OverlayProvider,
        ({String? selectedId, List<Map<String, dynamic>> wallets})>(
      selector: (_, p) =>
          (selectedId: p.selectedWalletId, wallets: p.availableWallets),
      builder: (context, data, _) => CustomDropdown<String>(
        value: data.selectedId,
        labelText: l10n.selectWallet,
        prefixIcon: const Icon(
          Icons.account_balance_wallet,
        ),
        itemsList:
            data.wallets.map((wallet) => wallet['id'].toString()).toList(),
        itemLabelBuilder: (String id) {
          final wallet = data.wallets.firstWhere(
            (w) => w['id'] == id,
            orElse: () => {'name': l10n.unknown},
          );
          return wallet['name'] ?? l10n.unknown;
        },
        onChanged: (val) =>
            context.read<OverlayProvider>().setSelectedWallet(val),
      ),
    );
  }
}

class _CommissionFieldWidget extends StatelessWidget {
  final FocusNode focusNode;

  const _CommissionFieldWidget({
    required this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CustomTextField(
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      labelText: l10n.commission,
      prefixIcon: const Icon(Icons.attach_money),
      onChanged: (val) => context.read<OverlayProvider>().setCommission(val),
    );
  }
}
