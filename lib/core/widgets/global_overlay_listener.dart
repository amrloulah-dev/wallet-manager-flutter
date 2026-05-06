import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/data/models/transaction_model.dart';

import 'package:walletmanager/core/utils/number_parser.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';

class GlobalOverlayListener extends StatefulWidget {
  final Widget child;
  final LocalStorageService? localStorage;

  const GlobalOverlayListener({
    super.key,
    required this.child,
    this.localStorage,
  });

  @override
  State<GlobalOverlayListener> createState() => _GlobalOverlayListenerState();
}

class _GlobalOverlayListenerState extends State<GlobalOverlayListener>
    with WidgetsBindingObserver {
  final ReceivePort _port = ReceivePort();
  late final LocalStorageService _storage;

  @override
  void initState() {
    super.initState();
    _storage = widget.localStorage ?? LocalStorageService.instance;
    WidgetsBinding.instance.addObserver(this);
    IsolateNameServer.removePortNameMapping('main_app_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'main_app_port');

    _port.listen((message) {
      if (message == 'update_ui') {
        _fetchAndApplyData();
      }
    }, onError: (error) {
      if (kDebugMode) debugPrint('❌ [PORT] GlobalOverlayListener port error: $error');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Apply any pending overlay tx from the unified vault.
      // DO NOT call refresh() here — it triggers a Firestore fetch that
      // overwrites optimistic mutations with stale cached data.
      _fetchAndApplyData();
    }
  }

  Future<void> _fetchAndApplyData() async {
    try {
      // Use LocalStorageService as the single source of truth for vault data.
      // This replaces the orphan 'pending_overlay_tx' SharedPreferences key.
      await _storage.reloadDisk();

      final data = _storage.readFromVault();
      if (data == null) return;

      if (mounted) {
        context.read<StatisticsProvider>().addTransactionOptimistically(data);

        final String nowStr = data['transactionDate']?.toString() ?? DateTime.now().toIso8601String();
        final tx = TransactionModel(
          transactionId: data['transactionId']?.toString() ?? '',
          storeId: data['storeId']?.toString() ?? '',
          walletId: data['walletId']?.toString() ?? '',
          transactionType: TransactionType.fromString(data['type']?.toString() ?? 'debit'), // ENUM refactor
          customerPhone: data['sender']?.toString(),
          customerName: data['customerName']?.toString(),
          amount: NumberParser.toDouble(data['amount']),
          commission: NumberParser.toDouble(data['commission']),
          serviceFee: 0.0, 
          paymentStatus: PaymentStatus.fromString(data['paymentStatus']?.toString() ?? 'paid'), // ENUM refactor
          transactionDate: DateTime.parse(nowStr),
          createdAt: DateTime.parse(nowStr),
          createdBy: 'SMS Auto',
        );
        
        context.read<TransactionProvider>().insertTransactionLocally(tx);

        // ── Zero-cost local wallet mutation ──
        // Apply the balance deduction directly to RAM.
        // NEVER call refresh() / fetchInitialWallets() here:
        // Firestore cache lag would overwrite our correct optimistic balance.
        final walletId = data['walletId']?.toString();
        final amount = NumberParser.toDouble(data['amount']);
        final type = data['type']?.toString(); // 'debit' = send, 'credit' = receive
        if (walletId != null && amount > 0 && type != null) {
          final isSend = type == 'debit';
          context.read<WalletProvider>().applyLocalDeduction(
            walletId,
            amount,
            isSend,
          );
        }
      }

      await _storage.clearVault();
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [GlobalOverlayListener] _fetchAndApplyData error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    IsolateNameServer.removePortNameMapping('main_app_port');
    _port.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
