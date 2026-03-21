import 'dart:convert';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/providers/statistics_provider.dart';
import 'package:walletmanager/providers/wallet_provider.dart';
import 'package:walletmanager/providers/transaction_provider.dart';

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
      // 1. Check vault just in case
      _fetchAndApplyData(); 
      // 2. Force the widget tree below to rebuild in case a frame was dropped!
      setState(() {}); 
    }
  }

  Future<void> _fetchAndApplyData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final txString = prefs.getString('pending_overlay_tx');
      if (txString == null) {
        return;
      }

      final data = jsonDecode(txString) as Map<String, dynamic>;

      if (mounted) {
        context.read<StatisticsProvider>().addTransactionOptimistically(data);
        context.read<WalletProvider>().updateWalletOptimistically(data);
        context.read<TransactionProvider>().insertTransactionLocally(data);
        
        // Phase 4: Manually force a clean fetch of true limits and values without streams
        context.read<WalletProvider>().refresh();
      }

      await prefs.remove('pending_overlay_tx');
    } catch (e) {
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
