import 'dart:convert';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalOverlayListener extends StatefulWidget {
  final Widget child;

  const GlobalOverlayListener({super.key, required this.child});

  @override
  State<GlobalOverlayListener> createState() => _GlobalOverlayListenerState();
}

class _GlobalOverlayListenerState extends State<GlobalOverlayListener>
    with WidgetsBindingObserver {
  final ReceivePort _port = ReceivePort();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    IsolateNameServer.removePortNameMapping('main_app_port');
    IsolateNameServer.registerPortWithName(_port.sendPort, 'main_app_port');

    _port.listen((message) {
      if (message == 'update_ui') {
        _fetchAndApplyData();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Apply any pending overlay tx from SharedPreferences vault.
      // DO NOT call refresh() here — it triggers a Firestore fetch that
      // overwrites optimistic mutations with stale cached data.
      _fetchAndApplyData();
    }
  }

  Future<void> _fetchAndApplyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final txString = prefs.getString('pending_overlay_tx');
      if (txString == null) return;

      final data = jsonDecode(txString) as Map<String, dynamic>;

      if (mounted) {
        context.read<StatisticsProvider>().addTransactionOptimistically(data);

        final String nowStr = data['transactionDate']?.toString() ?? DateTime.now().toIso8601String();
        final tx = TransactionModel(
          transactionId: data['transactionId']?.toString() ?? '',
          storeId: data['storeId']?.toString() ?? '',
          walletId: data['walletId']?.toString() ?? '',
          transactionType: data['type'] == 'debit' ? 'send' : 'receive',
          customerPhone: data['sender']?.toString(),
          customerName: data['customerName']?.toString(),
          amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
          commission: (data['commission'] as num?)?.toDouble() ?? 0.0,
          serviceFee: 0.0, 
          paymentStatus: data['paymentStatus']?.toString() ?? 'paid',
          transactionDate: Timestamp.fromDate(DateTime.parse(nowStr)),
          createdAt: Timestamp.fromDate(DateTime.parse(nowStr)),
          createdBy: 'SMS Auto',
        );
        
        context.read<TransactionProvider>().insertTransactionLocally(tx);

        // ── Zero-cost local wallet mutation ──
        // Apply the balance deduction directly to RAM.
        // NEVER call refresh() / fetchInitialWallets() here:
        // Firestore cache lag would overwrite our correct optimistic balance.
        final walletId = data['walletId']?.toString();
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
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

      await prefs.remove('pending_overlay_tx');
    } catch (e) {
      debugPrint('⚠️ [GlobalOverlayListener] _fetchAndApplyData error: $e');
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
