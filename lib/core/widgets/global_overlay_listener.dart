import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';

class GlobalOverlayListener extends StatefulWidget {
  final Widget child;

  const GlobalOverlayListener({super.key, required this.child});

  @override
  State<GlobalOverlayListener> createState() => _GlobalOverlayListenerState();
}

class _GlobalOverlayListenerState extends State<GlobalOverlayListener> {
  final ReceivePort _receivePort = ReceivePort();

  @override
  void initState() {
    super.initState();
    _setupOverlayListener();
  }

  void _setupOverlayListener() {
    IsolateNameServer.removePortNameMapping('overlay_tx_port');
    IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, 'overlay_tx_port');

    _receivePort.listen((message) {
      debugPrint("🔔 [MAIN APP] IsolateNameServer Received: $message");
      if (message is Map) {
        try {
          final data = Map<String, dynamic>.from(message);
          context.read<StatisticsProvider>().addTransactionOptimistically(data);
          context.read<WalletProvider>().updateWalletOptimistically(data);
          context.read<TransactionProvider>().insertTransactionLocally(data);
          debugPrint(
              "🚀 [MAIN APP] Optimistic updates applied via Native Port!");
        } catch (e) {
          debugPrint("❌ [MAIN APP] Error updating: $e");
        }
      }
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('overlay_tx_port');
    _receivePort.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
