import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/utils/error_translator.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/presentation/overlays/overlay_provider.dart';
import 'package:walletmanager/presentation/widgets/common/custom_text_field.dart';
import 'package:walletmanager/presentation/widgets/common/custom_dropdown.dart';
import 'package:walletmanager/presentation/widgets/common/custom_button.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/presentation/utils/wallet_extensions.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class TransactionOverlayScreen extends StatelessWidget {
  static final ThemeData _cachedLightTheme = ThemeData.light();

  const TransactionOverlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = sl.isRegistered<LocalStorageService>()
        ? sl<LocalStorageService>()
        : LocalStorageService.instance;
    // Determine language from local storage
    final languageCode = storage.languageCode ?? 'ar';

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
  late TextEditingController _commissionController;
  StreamSubscription? _overlaySubscription;

  @override
  void initState() {
    super.initState();
    _commissionFocusNode = FocusNode();
    _commissionController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _provider = context.read<OverlayProvider>();
      final storage = sl.isRegistered<LocalStorageService>()
          ? sl<LocalStorageService>()
          : LocalStorageService.instance;

      // 1. Read current active SMS from storage (Single-Item SSOT)
      final activeData = await storage.readCurrentActiveSms();
      if (activeData != null) {
        await _provider.ingestNewEvent(activeData);
      }

      // 2. Setup stream listener for incoming live events
      _overlaySubscription =
          FlutterOverlayWindow.overlayListener.listen((event) async {
        if (event != null && event is Map) {
          // 🛡️ Filter out internal broadcast actions to prevent stale state overrides
          if (event['action'] == 'local_deduct') return;

          _provider.ingestNewEvent(event);
        }
      }, onError: (error) {
        if (kDebugMode) {
          debugPrint('❌ [OVERLAY] overlayListener error: $error');
        }
      });

      if (mounted) {
        _commissionFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _overlaySubscription?.cancel();
    _commissionFocusNode.dispose();
    _commissionController.dispose();
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
            margin: const EdgeInsets.symmetric(horizontal: 12),
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 14.0, vertical: 16.0),
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
                              controller: _commissionController,
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
          final theme = Theme.of(context);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            final displayError = ErrorTranslator.getLocalizedString(
                context, provider.errorMessage!);

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        prefixIcon: const Icon(
          Icons.account_balance_wallet,
          size: 20,
        ),
        itemsList:
            data.wallets.map((wallet) => wallet['id'].toString()).toList(),
        itemWidgetBuilder: (context, String id) {
          final wallet = data.wallets.firstWhere(
            (w) => w['id']?.toString() == id,
            orElse: () => <String, dynamic>{},
          );
          return _buildWalletDropdownItem(context, wallet, l10n);
        },
        selectedItemWidgetBuilder: (context, String id) {
          final wallet = data.wallets.firstWhere(
            (w) => w['id']?.toString() == id,
            orElse: () => <String, dynamic>{},
          );
          return _buildWalletSelectedItem(context, wallet, l10n);
        },
        itemLabelBuilder: (String id) {
          final wallet = data.wallets.firstWhere(
            (w) => w['id']?.toString() == id,
            orElse: () => {'name': l10n.unknown},
          );
          final rawType = wallet['walletType']?.toString() ??
              wallet['type']?.toString() ??
              'other';
          final visuals = WalletProviderVisuals.fromRawType(rawType, l10n);
          final phone = wallet['phone']?.toString() ??
              wallet['phoneNumber']?.toString() ??
              wallet['name']?.toString() ??
              l10n.unknown;
          String label = '$phone (${visuals.label})';
          if (wallet['isFrozen'] == true) {
            label += ' ${l10n.walletIsFrozenShort}';
          }
          return label;
        },
        onChanged: (val) {
          if (val != null) {
            final wallet = data.wallets.firstWhere(
              (w) => w['id']?.toString() == val,
              orElse: () => {'isFrozen': false},
            );
            if (wallet['isFrozen'] == true) {
              final theme = Theme.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.walletIsFrozen,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onError)),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
              context.read<OverlayProvider>().setSelectedWallet(null);
              return;
            }
          }
          context.read<OverlayProvider>().setSelectedWallet(val);
        },
      ),
    );
  }

  Widget _buildWalletDropdownItem(
    BuildContext context,
    Map<String, dynamic> wallet,
    AppLocalizations l10n,
  ) {
    final rawType = wallet['walletType']?.toString() ??
        wallet['type']?.toString() ??
        'other';
    final visuals = WalletProviderVisuals.fromRawType(rawType, l10n);
    final phoneNumber = wallet['phone']?.toString() ??
        wallet['phoneNumber']?.toString() ??
        wallet['name']?.toString() ??
        '';
    final isFrozen = wallet['isFrozen'] == true;

    final providerColor = isFrozen ? Colors.grey : visuals.color;
    final providerIcon = visuals.icon;
    final providerLabel = isFrozen
        ? '${visuals.label} (${l10n.walletIsFrozenShort})'
        : visuals.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 1. Leading Provider Icon with subtle background tint
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(providerIcon, size: 18, color: providerColor),
          ),
          const SizedBox(width: 10),

          // 2. Phone Number (Guarded with LTR Unicode marker)
          Expanded(
            child: Text(
              '\u200E$phoneNumber\u200E',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isFrozen ? Colors.grey : null,
                  ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // 3. Trailing Provider Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: providerColor.withOpacity(0.2), width: 0.8),
            ),
            child: Text(
              providerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: providerColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletSelectedItem(
    BuildContext context,
    Map<String, dynamic> wallet,
    AppLocalizations l10n,
  ) {
    final rawType = wallet['walletType']?.toString() ??
        wallet['type']?.toString() ??
        'other';
    final visuals = WalletProviderVisuals.fromRawType(rawType, l10n);
    final phoneNumber = wallet['phone']?.toString() ??
        wallet['phoneNumber']?.toString() ??
        wallet['name']?.toString() ??
        '';
    final isFrozen = wallet['isFrozen'] == true;

    final providerColor = isFrozen ? Colors.grey : visuals.color;
    final providerIcon = visuals.icon;
    final providerLabel = isFrozen
        ? '${visuals.label} (${l10n.walletIsFrozenShort})'
        : visuals.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          // 1. Compact Leading Provider Icon
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: providerColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(providerIcon, size: 15, color: providerColor),
          ),
          const SizedBox(width: 4),

          // 2. Phone Number (Guarded with LTR Unicode marker)
          Expanded(
            flex: 3,
            child: Text(
              '\u200E$phoneNumber\u200E',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isFrozen ? Colors.grey : null,
                  ),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 4),

          // 3. Compact Trailing Provider Badge
          Flexible(
            flex: 2,
            fit: FlexFit.loose,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: providerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: providerColor.withOpacity(0.2), width: 0.8),
              ),
              child: Text(
                providerLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: providerColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionFieldWidget extends StatelessWidget {
  final FocusNode focusNode;
  final TextEditingController controller;

  const _CommissionFieldWidget({
    required this.focusNode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Sync provider's commission to controller
    final commission =
        context.select<OverlayProvider, double>((p) => p.commission);
    final currentTextVal = double.tryParse(controller.text) ?? 0.0;
    if (commission != currentTextVal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (commission == 0.0) {
          controller.clear();
        } else {
          controller.text =
              commission.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
        }
      });
    }

    return CustomTextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      labelText: l10n.commission,
      prefixIcon: const Icon(Icons.attach_money),
      onChanged: (val) => context.read<OverlayProvider>().setCommission(val),
    );
  }
}
