import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/sms_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../data/models/sim_wallet_config.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../l10n/arb/app_localizations.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/subscription_provider.dart';
import '../../../../core/constants/route_constants.dart';
import 'section_title.dart';

class SmsAutomationSection extends StatefulWidget {
  const SmsAutomationSection({super.key});

  @override
  State<SmsAutomationSection> createState() => _SmsAutomationSectionState();
}

class _SmsAutomationSectionState extends State<SmsAutomationSection> {
  final LocalStorageService _storage = LocalStorageService();
  bool _isEnabled = false;
  List<Map<String, dynamic>> _availableWallets = [];
  SimWalletConfig? _sim1Config;
  SimWalletConfig? _sim2Config;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    await _storage.initialize();
    final enabled = _storage.isSmsAutomationEnabled;
    final wallets = _storage.getCachedWalletLiteList();

    // Load current mappings
    final mappings = _storage.getSimMappings();

    final sim1 = mappings.where((m) => m.simSlotIndex == 0).firstOrNull;
    final sim2 = mappings.where((m) => m.simSlotIndex == 1).firstOrNull;

    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _availableWallets = wallets;
        _sim1Config = sim1;
        _sim2Config = sim2;
      });
    }
  }

  Future<void> _toggleSmsAutomation(bool value) async {
    if (value) {
      try {
        // Use init() as the single entry point for all required permissions
        final success = await SmsService().init();

        if (!success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.smsPermissionRequired),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Enable Logic
        await _storage.setSmsAutomationEnabled(true);
        setState(() {
          _isEnabled = true;
        });
      } catch (e, stack) {
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          operation: 'toggle_sms_automation',
        );
        if (mounted) {
          ToastUtils.showError(AppLocalizations.of(context)!.unexpectedError);
          // Revert switch if failed
          setState(() {
            _isEnabled = false;
          });
        }
      } finally {
        if (mounted) {
          // Cleanup or consistency checks
        }
      }
    } else {
      // Disable
      try {
        await _storage.setSmsAutomationEnabled(false);
        if (mounted) {
          setState(() {
            _isEnabled = false;
          });
        }
      } finally {
        if (mounted) {
          // Consistency
        }
      }
    }
  }

  Future<void> _updateMapping(int simSlot, String? walletId) async {
    if (walletId == null) return;

    try {
      // Find selected wallet details
      final wallet = _availableWallets.firstWhere((w) => w['id'] == walletId,
          orElse: () => {});
      if (wallet.isEmpty) return;

      final newConfig = SimWalletConfig(
        simSlotIndex: simSlot,
        walletId: walletId,
        walletName: wallet['name'] ?? 'Unknown',
        serviceProvider: wallet['type'] ?? 'Unknown',
        subscriptionId:
            null, // Depending on device capability, might update later
      );

      // Update list
      final mappings = _storage.getSimMappings();
      mappings.removeWhere((m) => m.simSlotIndex == simSlot);
      mappings.add(newConfig);

      await _storage.saveSimMappings(mappings);

      if (mounted) {
        setState(() {
          if (simSlot == 0) _sim1Config = newConfig;
          if (simSlot == 1) _sim2Config = newConfig;
        });
      }
    } finally {
      if (mounted) {
        // Consistency
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final subProvider = context.watch<SubscriptionProvider>();
    final isExpired = subProvider.isExpired;
    final isOwner = authProvider.isOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
            title: AppLocalizations.of(context)!.automationAndMessages),
        Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              GestureDetector(
                onTap: isExpired
                    ? () {
                        HapticFeedback.heavyImpact();
                        final l10n = AppLocalizations.of(context)!;
                        if (isOwner) {
                          ToastUtils.showError(l10n.upgradeRequiredToEnableSms);
                          Navigator.pushNamed(context, RouteConstants.upgradeScreen);
                        } else {
                          ToastUtils.showError(l10n.requestUpgradeFromOwner);
                        }
                      }
                    : null,
                child: AbsorbPointer(
                  absorbing: isExpired,
                  child: SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)!.enableAutoSmsReading,
                      style: AppTextStyles.bodyLarge,
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)!.autoDetectTransactions,
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                    ),
                    value: _isEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: isExpired ? null : _toggleSmsAutomation,
                  ),
                ),
              ),
              if (_isEnabled) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.linkSimToWallet,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      // SIM 1
                      _buildSimDropdown(0,
                          AppLocalizations.of(context)!.sim1Label, _sim1Config),
                      const SizedBox(height: 12),
                      // SIM 2
                      _buildSimDropdown(1,
                          AppLocalizations.of(context)!.sim2Label, _sim2Config),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimDropdown(
      int slot, String label, SimWalletConfig? currentConfig) {
    final String? currentId = currentConfig?.walletId;
    final bool valueExists = currentId != null && _availableWallets.any((w) => w['id'] == currentId);
    final String? safeValue = valueExists ? currentId : null;

    return DropdownButtonFormField<String>(
      value: safeValue,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _availableWallets.isEmpty
          ? [
              DropdownMenuItem(
                  value: null,
                  child: Text(AppLocalizations.of(context)!.noSavedWallets,
                      style: const TextStyle(fontSize: 12)))
            ]
          : _availableWallets.map((w) {
              return DropdownMenuItem<String>(
                value: w['id'],
                child: Text(
                  w['name'] ?? 'Unknown',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              );
            }).toList(),
      onChanged: (val) => _updateMapping(slot, val),
    );
  }
}
