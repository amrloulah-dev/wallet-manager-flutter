import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/core/utils/number_parser.dart';
import 'package:walletmanager/core/utils/number_formatter.dart';
import 'package:walletmanager/domain/usecases/overlay_usecase.dart';
import 'package:walletmanager/core/state/safe_change_notifier.dart';
import 'package:walletmanager/core/errors/app_error_handler.dart';
import 'package:walletmanager/core/enums/user_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';
import 'package:walletmanager/data/models/wallet_model.dart';

class OverlayProvider extends SafeChangeNotifier {
  final LocalStorageService _localStorageService;
  final OverlayUseCase _overlayUseCase;

  OverlayProvider({
    OverlayUseCase? overlayUseCase,
    LocalStorageService? localStorageService,
  })  : _overlayUseCase = overlayUseCase ?? sl<OverlayUseCase>(),
        _localStorageService = localStorageService ??
            (sl.isRegistered<LocalStorageService>()
                ? sl<LocalStorageService>()
                : LocalStorageService());

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

  // Session Cache
  String? _cachedUserId;
  String? _cachedStoreId;
  String? _cachedUserName;
  UserRole? _cachedUserRole;

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

  /// Guarded notification that respects the fetch shield.
  /// When [_blockAutoFetch] is true, notifications are suppressed
  /// to prevent unnecessary janky UI rebuilds during batch state mutations.
  void _guardedNotify() {
    if (_blockAutoFetch && _errorMessage == null) {
      if (kDebugMode) {
        debugPrint('🛡️ [Fetch Shield] _blockAutoFetch active — suppressed '
            'safeNotify() to prevent unnecessary janky UI rebuilds');
      }
      return;
    }
    safeNotify();
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
    _type = data['type']?.toString() ?? 'credit';

    if (kDebugMode) {
      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: '
          'raw data=[SENSITIVE] | parsed amount=[SENSITIVE], sender=[SENSITIVE], type=$_type');
    }

    _isLoading = true;

    _blockAutoFetch = false;
    _guardedNotify();
    _blockAutoFetch = true;

    try {
      if (!_isStorageInitialized) {
        await _localStorageService.initialize();
        _isStorageInitialized = true;
      }

      await _localStorageService.reloadDisk();

      // Cache session data to avoid sync I/O during submission
      _cachedUserId = _localStorageService.userId;
      _cachedStoreId = _localStorageService.storeId;
      _cachedUserName = _localStorageService.userName;
      _cachedUserRole = _localStorageService.userRole;

      if (_localStorageService.subIsSuspended ||
          !_localStorageService.subSmsEnabled) {
        if (kDebugMode) {
          debugPrint(
              '🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: SMS gating failed. Aborting overlay.');
        }
        await FlutterOverlayWindow.closeOverlay();
        return;
      }

      _availableWallets = _localStorageService.getCachedWalletLiteList();

      String? passedId = data['walletId']?.toString();
      if (passedId != null && passedId.trim().isEmpty) passedId = null;

      final bool exists =
          passedId != null && _availableWallets.any((w) => w['id'] == passedId);

      if (exists) {
        _selectedWalletId = passedId;
        final selectedWallet =
            _availableWallets.firstWhere((w) => w['id'] == passedId);
        final rawWalletType = selectedWallet['walletType']?.toString() ??
            selectedWallet['type']?.toString() ??
            'vodafone_cash';
        final walletType = WalletType.fromString(rawWalletType);
        final settings = sl<PlatformSettingsProvider>().settings;
        _commission = FeeCalculator.calculateTransactionFee(
          amount: _amount,
          sourceWalletType: walletType.dbValue,
          receiverPhone: _sender,
          settings: settings,
        );
        if (kDebugMode) {
          debugPrint('🔥 [TX_FLOW] [overlay_provider] -> ingestNewEvent: '
              'auto-selected walletId=$passedId, walletType=${walletType.name}, '
              'calculatedCommission=$_commission');
        }

        final wallet = WalletModel.fromWalletStatus(
          walletId: passedId,
          storeId: _cachedStoreId ?? '',
          phoneNumber: selectedWallet['phone']?.toString() ?? '',
          walletType: rawWalletType,
          walletStatus: selectedWallet['walletStatus']?.toString() ??
              selectedWallet['status']?.toString() ??
              'active',
          balance: 0.0,
          createdBy: _cachedUserName ?? 'SMS Auto',
          settings: settings,
        );

        final dynamicLimits = wallet.getDynamicNetworkLimits(settings);
        final isInstaPay = walletType == WalletType.instaPay;

        if (_amount > dynamicLimits.maxPerTransaction) {
          final formattedLimit =
              NumberFormatter.formatAmount(dynamicLimits.maxPerTransaction);
          if (isInstaPay) {
            _errorMessage =
                "overlay_error_amount_limit_instapay:$formattedLimit";
          } else {
            _errorMessage =
                "overlay_error_amount_limit_telecom:$formattedLimit";
          }
        }
      } else {
        _selectedWalletId = null;
      }
    } catch (e, stack) {
      AppErrorHandler.logSilentError(
          e.toString(), 'OverlayProvider: Failed to ingest event',
          stackTrace: stack);
      _errorMessage = 'overlay_error_load_failed';
    } finally {
      _isLoading = false;
      _blockAutoFetch = false;
      _guardedNotify();
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
    _guardedNotify();
  }

  void setSelectedWallet(String? walletId) {
    _selectedWalletId = walletId;
    if (kDebugMode) {
      debugPrint('🔥 [TX_FLOW] [overlay_provider] -> setSelectedWallet: '
          'new walletId=$walletId, current amount=$_amount');
    }

    if (walletId != null && _amount > 0) {
      final match = _availableWallets.cast<Map<String, dynamic>?>().firstWhere(
            (w) => w?['id'] == walletId,
            orElse: () => null,
          );
      if (match != null) {
        final rawWalletType =
            match['walletType']?.toString() ?? 'vodafone_cash';
        final walletType = WalletType.fromString(rawWalletType);
        final settings = sl<PlatformSettingsProvider>().settings;
        _commission = FeeCalculator.calculateTransactionFee(
          amount: _amount,
          sourceWalletType: walletType.dbValue,
          receiverPhone: _sender,
          settings: settings,
        );
        if (kDebugMode) {
          debugPrint('🔥 [TX_FLOW] [overlay_provider] -> setSelectedWallet: '
              'walletType=${walletType.name}, recalculatedCommission=$_commission');
        }
      }
    } else {
      _commission = 0.0;
      if (kDebugMode) {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> setSelectedWallet: '
            'walletId is null or amount=0, commission reset to 0.0');
      }
    }

    _guardedNotify();
  }

  Future<void> submitTransaction() async {
    if (_selectedWalletId == null) {
      _errorMessage = 'pleaseSelectWallet';
      _guardedNotify();
      return;
    }

    if (_cachedUserId == null || _cachedStoreId == null) {
      _errorMessage = 'authErrorRelogin';
      _guardedNotify();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _guardedNotify();

    try {
      final result = await _overlayUseCase.execute(
        storeId: _cachedStoreId!,
        userId: _cachedUserId!,
        userName: _cachedUserName ?? 'Unknown',
        userRole: _cachedUserRole?.name ?? UserRole.employee.name,
        selectedWalletId: _selectedWalletId!,
        type: _type,
        amount: _amount,
        commission: _commission,
        sender: _sender,
        availableWallets: _availableWallets,
      );

      final SendPort? sendPort =
          IsolateNameServer.lookupPortByName('main_app_port');
      if (sendPort != null) {
        sendPort.send('update_ui');
        if (kDebugMode) {
          debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
              'IsolateNameServer ping sent to main_app_port');
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
              'WARNING — main_app_port SendPort is null, ping NOT sent');
        }
      }

      if (kDebugMode) {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'shareData(local_deduct) → walletId=$_selectedWalletId, '
            'deduction=${result.totalDeduction}, isSend=${result.isSend}');
      }

      _isLoading = false;
      _commission = 0.0;
      _guardedNotify();

      FlutterOverlayWindow.shareData({
        "action": "local_deduct",
        "walletId": _selectedWalletId,
        "amount": result.totalDeduction,
        "isSend": result.isSend,
        "blockAutoFetch": true,
      });

      if (kDebugMode) {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'closing overlay window ...');
      }
      await FlutterOverlayWindow.closeOverlay();
    } catch (e, stack) {
      AppErrorHandler.handle(e,
          stackTrace: stack,
          operation: 'OverlayProvider: Failed to submit transaction');
      _errorMessage = 'overlay_error_submit_failed';
      if (kDebugMode) {
        debugPrint('🔥 [TX_FLOW] [overlay_provider] -> submitTransaction: '
            'CATCH → $e');
      }
    } finally {
      _isLoading = false;
      _guardedNotify();
    }
  }

  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint(
          '🔥 [TX_FLOW] [overlay_provider] -> dispose(): Cleaning up overlay provider resources.');
    }
    // Any future StreamSubscriptions or Timers specific to OverlayProvider MUST be cancelled here.
    super.dispose();
  }

  Future<void> close() async {
    await _localStorageService.clearVault();
    await FlutterOverlayWindow.closeOverlay();
  }
}
