import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/utils/number_parser.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';

class OverlayProvider with ChangeNotifier {
  final LocalStorageService _localStorageService = LocalStorageService();
  final OverlayUseCase _overlayUseCase;

  OverlayProvider({OverlayUseCase? overlayUseCase})
      : _overlayUseCase = overlayUseCase ?? sl<OverlayUseCase>();

  bool _isLoading = false;
  bool _isStorageInitialized = false;
  String? _errorMessage;
  String? _successMessage;

  // Transaction Data
  double _amount = 0.0;
  String _sender = '';
  String _type = ''; // credit/debit
  String? _selectedWalletId;
  double _commission = 0.0;
  List<Map<String, dynamic>> _availableWallets = [];

  bool _blockAutoFetch = false;

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

  @override
  void notifyListeners() {
    if (_blockAutoFetch) {
      debugPrint('🛡️ [Fetch Shield] _blockAutoFetch active — suppressed '
          'notifyListeners() to prevent unnecessary janky UI rebuilds');
      return;
    }
    super.notifyListeners();
  }

  void reset() {
    _amount = 0.0;
    _sender = '';
    _type = '';
    _selectedWalletId = null;
    _commission = 0.0;
    _errorMessage = null;
    _successMessage = null;
    _isLoading = false;
  }

  Future<void> ingestNewEvent(Map<dynamic, dynamic> data) async {
    _blockAutoFetch = true;
    reset();

    _amount = NumberParser.toDouble(data['amount']);
    _sender = data['sender']?.toString() ?? 'Unknown';
    _type   = data['type']?.toString()   ?? 'credit';

    debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: '
        'raw data=$data | parsed amount=$_amount, sender=$_sender, type=$_type');

    _isLoading = true;
    
    _blockAutoFetch = false;
    notifyListeners();
    _blockAutoFetch = true;

    try {
      if (!_isStorageInitialized) {
        await _localStorageService.initialize();
        _isStorageInitialized = true;
      }

      await LocalStorageService.instance.reloadDisk();

      if (_localStorageService.subIsSuspended || !_localStorageService.subSmsEnabled) {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: SMS gating failed. Aborting overlay.');
        await FlutterOverlayWindow.closeOverlay();
        return;
      }

      _availableWallets = LocalStorageService.instance.getCachedWalletLiteList();

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
          _errorMessage = "overlay_error_amount_limit_instapay";
        } else if (isTelecom && _amount > 60000) {
          _errorMessage = "overlay_error_amount_limit_telecom";
        }
      } else {
        _selectedWalletId = null;
      }
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';

    } finally {
      _isLoading = false;
      _blockAutoFetch = false;
      notifyListeners();
    }
  }

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
      final result = await _overlayUseCase.execute(
        storeId: storeId,
        userId: userId,
        userName: userName,
        userRole: userRole,
        selectedWalletId: _selectedWalletId!,
        type: _type,
        amount: _amount,
        commission: _commission,
        sender: _sender,
        availableWallets: _availableWallets,
      );

      final SendPort? sendPort = IsolateNameServer.lookupPortByName('main_app_port');
      if (sendPort != null) {
        sendPort.send('update_ui');
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'IsolateNameServer ping sent to main_app_port');
      } else {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'WARNING — main_app_port SendPort is null, ping NOT sent');
      }

      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
          'shareData(local_deduct) → walletId=$_selectedWalletId, '
          'deduction=${result.totalDeduction}, isSend=${result.isSend}');
      
      _isLoading = false;
      notifyListeners();
      
      FlutterOverlayWindow.shareData({
        "action": "local_deduct",
        "walletId": _selectedWalletId,
        "amount": result.totalDeduction,
        "isSend": result.isSend,
        "blockAutoFetch": true,
      });

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
