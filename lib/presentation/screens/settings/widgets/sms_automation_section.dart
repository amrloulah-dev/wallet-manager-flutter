import 'package:flutter/material.dart';
import '../../../../core/services/sms_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/toast_utils.dart';
import '../../../../data/models/sim_wallet_config.dart';
import '../../../../data/services/local_storage_service.dart';
import '../../../../l10n/arb/app_localizations.dart';
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
      // 1. Request SMS Permission FIRST
      final smsGranted = await SmsService().requestSmsPermission();

      if (!smsGranted) {
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

      // Enable
      try {
        // 2. Request Overlay Permission SECOND
        await SmsService().requestOverlayPermission();

        // 3. Enable Logic
        await _storage.setSmsAutomationEnabled(true);
        setState(() {
          _isEnabled = true;
        });

        // Ensure service is listening
        await SmsService().init();
      } catch (e) {
        if (mounted) {
          ToastUtils.showError('Required permissions missing: $e');
        }
        // Revert switch if failed
        setState(() {
          _isEnabled = false;
        });
      }
    } else {
      // Disable
      await _storage.setSmsAutomationEnabled(false);
      setState(() {
        _isEnabled = false;
      });
    }
  }

  Future<void> _updateMapping(int simSlot, String? walletId) async {
    if (walletId == null) return;

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

    setState(() {
      if (simSlot == 0) _sim1Config = newConfig;
      if (simSlot == 1) _sim2Config = newConfig;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              SwitchListTile(
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
                onChanged: _toggleSmsAutomation,
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
                      _buildSimDropdown(
                          0, AppLocalizations.of(context)!.sim1Label, _sim1Config),
                      const SizedBox(height: 12),
                      // SIM 2
                      _buildSimDropdown(
                          1, AppLocalizations.of(context)!.sim2Label, _sim2Config),
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
    return DropdownButtonFormField<String>(
      value: currentConfig?.walletId,
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
