import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/sms_service.dart';
import '../../../../core/services/background_service.dart';
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
import 'sms_parser_playground_card.dart'; // [TEMP DIAGNOSTIC]

class SmsAutomationSection extends StatefulWidget {
  const SmsAutomationSection({super.key});

  @override
  State<SmsAutomationSection> createState() => _SmsAutomationSectionState();
}

class _SmsAutomationSectionState extends State<SmsAutomationSection> {
  final LocalStorageService _storage = LocalStorageService();
  bool _isEnabled = false;
  bool _isToggling = false;
  List<Map<String, dynamic>> _availableWallets = [];
  SimWalletConfig? _sim1Config;
  SimWalletConfig? _sim2Config;
  // [TEMP DIAGNOSTIC]
  List<Map<String, dynamic>> _rejectedLogs = [];

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    await _storage.initialize();
    final enabled = _storage.isSmsAutomationEnabled;
    final wallets = _storage.getCachedWalletLiteList();

    // [TEMP DIAGNOSTIC] Reload and read rejected SMS logs
    await _storage.reloadDisk();
    final rejectedLogs = _storage.getRejectedSmsLogs();

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
        // [TEMP DIAGNOSTIC]
        _rejectedLogs = rejectedLogs;
      });
    }
  }

  // [TEMP DIAGNOSTIC]
  Future<void> _refreshDiagnosticLogs() async {
    await _storage.reloadDisk();
    final logs = _storage.getRejectedSmsLogs();
    if (mounted) {
      setState(() {
        _rejectedLogs = logs;
      });
    }
  }

  Future<void> _toggleSmsAutomation(bool value) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);

    if (value) {
      // ── ENABLE PATH ──────────────────────────────────────────
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

        // Persist state BEFORE starting service so onStart guard passes
        await _storage.setSmsAutomationEnabled(true);
        setState(() {
          _isEnabled = true;
        });

        // Instant Dynamic Start
        await startBackgroundMonitoring();

        if (mounted) {
          ToastUtils.showSuccess(
            AppLocalizations.of(context)!.smsMonitoringActivated,
          );
        }
      } catch (e, stack) {
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          operation: 'toggle_sms_automation_enable',
        );
        // Full rollback: revert storage + UI
        await _storage.setSmsAutomationEnabled(false);
        if (mounted) {
          setState(() {
            _isEnabled = false;
          });
          ToastUtils.showError(
            AppLocalizations.of(context)!.smsServiceStartFailed,
          );
        }
      } finally {
        if (mounted) setState(() => _isToggling = false);
      }
    } else {
      // ── DISABLE PATH ─────────────────────────────────────────
      try {
        await _storage.setSmsAutomationEnabled(false);
        if (mounted) {
          setState(() {
            _isEnabled = false;
          });
        }

        // Instant Dynamic Stop
        await stopBackgroundMonitoring();
      } catch (e, stack) {
        AppErrorHandler.handle(
          e,
          stackTrace: stack,
          operation: 'toggle_sms_automation_disable',
        );
      } finally {
        if (mounted) setState(() => _isToggling = false);
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
                          Navigator.pushNamed(
                              context, RouteConstants.upgradeScreen);
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
                      style:
                          AppTextStyles.bodySmall.copyWith(color: Colors.grey),
                    ),
                    value: _isEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (isExpired || _isToggling)
                        ? null
                        : _toggleSmsAutomation,
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
        // [TEMP DIAGNOSTIC]
        const SmsParserPlaygroundCard(),
        // [TEMP DIAGNOSTIC]
        _buildDiagnosticCard(),
      ],
    );
  }

  // [TEMP DIAGNOSTIC]
  Widget _buildDiagnosticCard() {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bug_report_outlined,
                  color: AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'سجل الرسائل المرفوضة (Diagnostic Logs)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _rejectedLogs.isEmpty
                        ? AppColors.divider(context).withAlpha(50)
                        : AppColors.warning.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '(${_rejectedLogs.length} messages)',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _rejectedLogs.isEmpty
                          ? AppColors.textSecondary(context)
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'تحديث السجل',
                  onPressed: _refreshDiagnosticLogs,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('نسخ السجل'),
                  onPressed: () async {
                    if (_rejectedLogs.isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('لا توجد رسائل مرفوضة حالياً'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                      return;
                    }

                    final jsonText = const JsonEncoder.withIndent('  ')
                        .convert(_rejectedLogs);
                    try {
                      await Clipboard.setData(ClipboardData(text: jsonText));
                    } catch (e, stack) {
                      AppErrorHandler.logSilentError(
                        e.toString(),
                        'SmsAutomationSection.copyDiagnosticLogs',
                        stackTrace: stack,
                      );
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم نسخ سجل الرسائل المرفوضة بنجاح'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('مسح'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  onPressed: _rejectedLogs.isEmpty
                      ? null
                      : () async {
                          await _storage.clearRejectedSmsLogs();
                          if (mounted) {
                            setState(() {
                              _rejectedLogs = [];
                            });
                            ToastUtils.showSuccess(
                              'تم مسح سجل الرسائل المرفوضة',
                            );
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimDropdown(
      int slot, String label, SimWalletConfig? currentConfig) {
    final String? currentId = currentConfig?.walletId;
    final bool valueExists =
        currentId != null && _availableWallets.any((w) => w['id'] == currentId);
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
