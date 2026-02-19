import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class OverlayProvider with ChangeNotifier {
  final LocalStorageService _localStorageService = LocalStorageService();
  final TransactionRepository _transactionRepository = TransactionRepository();

  bool _isLoading = false;
  bool _isInitialized = false;
  String? _errorMessage;

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
  double get amount => _amount;
  String get sender => _sender;
  String? get selectedWalletId => _selectedWalletId;
  double get commission => _commission;
  List<Map<String, dynamic>> get availableWallets => _availableWallets;

  /// Loads data passed from the background service
  Future<void> loadData(dynamic arguments) async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Initialize Local Storage (Overlay is separate engine)
      await _localStorageService.initialize();

      // 2. Load Cached Wallets
      _availableWallets = _localStorageService.getCachedWalletLiteList();

      if (arguments != null && arguments is Map) {
        _amount = (arguments['amount'] as num?)?.toDouble() ?? 0.0;
        _sender = arguments['sender'] as String? ?? 'Unknown';
        // 'credit' (Receive) or 'debit' (Send)
        _type = arguments['type'] as String? ?? 'credit';

        // Smart Selection Logic
        String? passedId = arguments['walletId'] as String?;
        if (passedId != null && passedId.trim().isEmpty) passedId = null;

        // Check if passedId actually exists in our list
        bool exists = _availableWallets.any((w) => w['id'] == passedId);

        if (exists) {
          _selectedWalletId = passedId;
        } else if (_availableWallets.isNotEmpty) {
          // FALLBACK: Select the first wallet if match fails or id is null
          // This prevents crash when Dropdown receives a value not in items
          _selectedWalletId = _availableWallets.first['id'];
        } else {
          // No wallets available at all.
          _selectedWalletId = null;
        }
      }

      _isInitialized = true;
    } catch (e) {
      _errorMessage = 'Failed to load data: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCommission(String value) {
    _commission = double.tryParse(value) ?? 0.0;
    notifyListeners();
  }

  void setSelectedWallet(String? walletId) {
    _selectedWalletId = walletId;
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

      // Map SMS Type to TransactionModel Type
      // DTO: credit (Receive) -> 'receive'
      // DTO: debit (Send) -> 'send'
      String transactionType = 'receive';
      if (_type == 'debit') {
        transactionType = 'send';
      }

      final now = Timestamp.now();

      final transaction = TransactionModel(
        transactionId:
            DateTime.now().millisecondsSinceEpoch.toString(), // Temp ID
        storeId: storeId,
        walletId: _selectedWalletId!,
        transactionType: transactionType,
        customerPhone: _sender, // The counterparty
        amount: _amount,
        commission: _commission,
        serviceFee: 0.0, // Network fee not captured
        paymentStatus: 'paid', // Instant
        transactionDate: now,
        createdAt: now,
        createdBy: userName ?? 'SMS Auto',
        createdById: userId,
        createdByName: userName,
        creatorRole: userRole,
        isDeleted: false,
        notes: 'Automated via SMS',
      );

      await _transactionRepository.createTransaction(transaction);

      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      _errorMessage = 'Error saving: $e';
    } finally {
      if (hasListeners) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void close() async {
    await FlutterOverlayWindow.closeOverlay();
  }
}
