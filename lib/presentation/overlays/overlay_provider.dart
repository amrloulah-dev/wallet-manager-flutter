import 'dart:convert';
import 'dart:ui';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
// BotToast is NOT initialized in the overlay isolate — do not use here.

class OverlayProvider with ChangeNotifier {
  final LocalStorageService _localStorageService = LocalStorageService();

  bool _isLoading = false;
  bool _isStorageInitialized = false; // Only guards one-time storage init
  String? _errorMessage;
  String? _successMessage;

  // Transaction Data
  double _amount = 0.0;
  String _sender = '';
  String _type = ''; // credit/debit
  String? _selectedWalletId;
  double _commission = 0.0;
  List<Map<String, dynamic>> _availableWallets = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  double get amount => _amount;
  String get sender => _sender;
  String get type => _type;
  String? get selectedWalletId => _selectedWalletId;
  double get commission => _commission;
  List<Map<String, dynamic>> get availableWallets => _availableWallets;

  // ---------------------------------------------------------------------------
  // RESET — Wipes all transaction-specific fields to prevent stale state.
  // Called at the start of every new overlay event.
  // ---------------------------------------------------------------------------
  void reset() {
    _amount = 0.0;
    _sender = '';
    _type = '';
    _selectedWalletId = null;
    _commission = 0.0;
    _errorMessage = null;
    _successMessage = null;
    _isLoading = false;
    // NOTE: _availableWallets and _isStorageInitialized are NOT reset.
    // The wallet list is session-level cache and does not change per-SMS.
  }

  // ---------------------------------------------------------------------------
  // INGEST NEW EVENT — The single entry-point for every overlay activation.
  //   1. reset()  → guarantees no stale data
  //   2. parse    → reads new SMS fields
  //   3. init     → loads wallets (only once per engine lifetime)
  //   4. select   → picks the correct wallet
  //   5. notify   → rebuilds UI
  // ---------------------------------------------------------------------------
  Future<void> ingestNewEvent(Map<dynamic, dynamic> data) async {
    reset();

    // --- Parse incoming SMS data ---
    _amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    _sender = data['sender']?.toString() ?? 'Unknown';
    _type   = data['type']?.toString()   ?? 'credit';

    debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: '
        'raw data=$data | parsed amount=$_amount, sender=$_sender, type=$_type');

    _isLoading = true;
    notifyListeners(); // Show loading UI immediately with new amount/sender

    try {
      // One-time storage + wallet cache init
      if (!_isStorageInitialized) {
        await _localStorageService.initialize();
        _isStorageInitialized = true;
      }

      // Force the Isolate to flush its RAM and read the latest disk state from the Main App
      await LocalStorageService.instance.reloadDisk();

      // Refresh wallet list on every event (cheap local read)
      _availableWallets = LocalStorageService.instance.getCachedWalletLiteList();

      // Smart wallet selection
      String? passedId = data['walletId']?.toString();
      if (passedId != null && passedId.trim().isEmpty) passedId = null;

      final bool exists = _availableWallets.any((w) => w['id'] == passedId);

      if (exists) {
        _selectedWalletId = passedId;
        final selectedWallet = _availableWallets.firstWhere((w) => w['id'] == passedId);
        final walletType = selectedWallet['walletType']?.toString() ?? 'vodafone_cash';
        _commission = FeeCalculator.calculateTransactionFee(
          amount: _amount,
          sourceWalletType: walletType,
          receiverPhone: _sender,
        );
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: '
            'auto-selected walletId=$passedId, walletType=$walletType, '
            'calculatedCommission=$_commission');

        final isInstaPay = walletType == 'instapay';
        final isTelecom = ['vodafone_cash', 'orange_cash', 'etisalat_cash', 'we_pay'].contains(walletType);
        
        if (isInstaPay && _amount > 70000) {
          _errorMessage = "المبلغ يتخطى الحد الأقصى للمعاملة الواحدة";
        } else if (isTelecom && _amount > 60000) {
          _errorMessage = "المبلغ يتخطى الحد الأقصى للمعاملة الواحدة";
        }
      } else {
        _selectedWalletId = null; // Prevent Dropdown assertion crashes
      }
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';

    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// @deprecated — Use [ingestNewEvent] instead. Kept for backward compat.
  @Deprecated('Use ingestNewEvent() which properly resets stale state.')
  Future<void> loadData(dynamic arguments) async {
    if (arguments == null) return;
    if (arguments is Map) {
      await ingestNewEvent(arguments);
    }
  }

  void setCommission(String value) {
    _commission = double.tryParse(value) ?? 0.0;
    notifyListeners();
  }

  void setSelectedWallet(String? walletId) {
    _selectedWalletId = walletId;
    debugPrint('🔥 [TX_FLOW] [overlay_provider] -> setSelectedWallet: '
        'new walletId=$walletId, current amount=$_amount');

    // Recalculate commission for the newly selected wallet
    if (walletId != null && _amount > 0) {
      final match = _availableWallets.cast<Map<String, dynamic>?>().firstWhere(
            (w) => w?['id'] == walletId,
            orElse: () => null,
          );
      if (match != null) {
        final walletType = match['walletType']?.toString() ?? 'vodafone_cash';
        _commission = FeeCalculator.calculateTransactionFee(
          amount: _amount,
          sourceWalletType: walletType,
          receiverPhone: _sender,
        );
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> setSelectedWallet: '
            'walletType=$walletType, recalculatedCommission=$_commission');
      }
    } else {
      _commission = 0.0;
      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> setSelectedWallet: '
          'walletId is null or amount=0, commission reset to 0.0');
    }

    notifyListeners();
  }

  Future<void> submitTransaction() async {
    if (_selectedWalletId == null) {
      _errorMessage = 'Please select a wallet';
      notifyListeners();
      return;
    }

    final userId = _localStorageService.userId;
    final storeId = _localStorageService.storeId;
    final userName = _localStorageService.userName;
    final userRole = _localStorageService.userRole;

    if (userId == null || storeId == null) {
      _errorMessage = 'Session invalid. Please login again inside the app.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Initialize Firebase Service (which inits Firebase App and instances)
      // This is crucial because we are in a separate isolate.
      if (!FirebaseService().isInitialized) {
        await FirebaseService().initialize();
      }

      String transactionType = _type == 'debit' ? 'send' : 'receive';
      final now = Timestamp.now();
      final txId = DateTime.now().millisecondsSinceEpoch.toString();

      final match = _availableWallets.cast<Map<String, dynamic>?>().firstWhere(
            (w) => w?['id'] == _selectedWalletId,
            orElse: () => null,
          );
      final walletType = match?['walletType']?.toString() ?? 'vodafone_cash';
      
      final calculatedServiceFee = FeeCalculator.calculateTransactionFee(
        amount: _amount,
        sourceWalletType: walletType,
        receiverPhone: _sender,
      );

      final newTransaction = TransactionModel(
        transactionId: txId,
        storeId: storeId,
        walletId: _selectedWalletId!,
        transactionType: transactionType,
        customerPhone: _sender,
        amount: _amount,
        commission: _commission,
        serviceFee: calculatedServiceFee,
        paymentStatus: 'paid',
        transactionDate: now,
        createdAt: now,
        createdBy: userName ?? 'SMS Auto',
        createdById: userId,
        createdByName: userName,
        creatorRole: userRole,
        isDeleted: false,
        notes: 'Automated via SMS',
      );

      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
          'FINAL PAYLOAD | txId=$txId, walletId=${_selectedWalletId}, '
          'type=$transactionType, amount=$_amount, commission=$_commission, '
          'sender=$_sender, storeId=$storeId');

      await TransactionRepository().createTransaction(newTransaction);

      // 6. Save to Vault
      final prefs = await SharedPreferences.getInstance();
      
      // CAUTION: Ensure variables like txId and storeId are actually defined in this scope!
      final txData = jsonEncode({
        'transactionId': txId, // Check if this exists
        'amount': _amount,
        'commission': _commission,
        'type': _type,
        'walletId': _selectedWalletId,
        'sender': _sender,
        'transactionDate': now.toDate().toIso8601String(),
        'storeId': storeId, // Prevent null crash
        'paymentStatus': 'paid',
        'customerName': '',
      });

      await prefs.setString('pending_overlay_tx', txData);

      // 7. Send Ping
      final SendPort? sendPort = IsolateNameServer.lookupPortByName('main_app_port');
      if (sendPort != null) {
        sendPort.send('update_ui');
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'IsolateNameServer ping sent to main_app_port');
      } else {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'WARNING — main_app_port SendPort is null, ping NOT sent');
      }

      // 8. Notify main app to refresh wallets via overlay data channel
      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
          'shareData(refresh_wallets) → broadcasting to main isolate');
      
      // Target 2: Force Immediate UI State Change in Overlay
      _isLoading = false;
      notifyListeners();
      
      await FlutterOverlayWindow.shareData({"action": "refresh_wallets"});

      // 9. Close Overlay — MUST be the very last await in the try block
      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
          'closing overlay window ...');
      await FlutterOverlayWindow.closeOverlay();

    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
          'CATCH → $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void close() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}
