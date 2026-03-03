import 'dart:ui';
import 'dart:isolate';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';

class OverlayProvider with ChangeNotifier {
  final LocalStorageService _localStorageService = LocalStorageService();

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
  String get type => _type;
  String? get selectedWalletId => _selectedWalletId;
  double get commission => _commission;
  List<Map<String, dynamic>> get availableWallets => _availableWallets;

  /// Loads data passed from the background service
  Future<void> loadData(dynamic arguments) async {
    if (arguments == null) return;

    // Deduplication Check: Prevent UI reset if the same event is received twice
    final incomingAmount = (arguments['amount'] as num?)?.toDouble() ?? 0.0;
    final incomingSender = arguments['sender']?.toString() ?? 'Unknown';

    if (_amount == incomingAmount && _sender == incomingSender) {
      debugPrint(
          ">>> OverlayProvider: Duplicate event received. Ignoring to prevent UI reset.");
      return;
    }

    // Set immediately to prevent race conditions before async operations
    if (arguments is Map) {
      _amount = incomingAmount;
      _sender = incomingSender;
    }

    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Initialize Local Storage (Overlay is separate engine)
      await _localStorageService.initialize();

      // 2. Load Cached Wallets
      _availableWallets = _localStorageService.getCachedWalletLiteList();

      if (arguments is Map) {
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

      String transactionType = _type == 'debit' ? 'send' : 'receive';
      final now = Timestamp.now();
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 1. Transaction Document
      final txId = DateTime.now().millisecondsSinceEpoch.toString();
      final transactionRef = firestore.collection('transactions').doc(txId);

      final transactionData = {
        'transactionId': txId,
        'storeId': storeId,
        'walletId': _selectedWalletId!,
        'transactionType': transactionType,
        'customerPhone': _sender,
        'amount': _amount,
        'commission': _commission,
        'serviceFee': 0.0,
        'paymentStatus': 'paid',
        'transactionDate': now,
        'createdAt': now,
        'createdBy': userName ?? 'SMS Auto',
        'createdById': userId,
        'createdByName': userName,
        'creatorRole': userRole,
        'isDeleted': false,
        'notes': 'Automated via SMS',
      };
      batch.set(transactionRef, transactionData);

      // 2. Wallet Document Update (Adjusting balance & Limits)
      final walletRef = firestore.collection('wallets').doc(_selectedWalletId!);
      double balanceChange = transactionType == 'send' ? -_amount : _amount;

      final walletUpdate = <String, dynamic>{
        'balance': FieldValue.increment(balanceChange),
        'stats.totalTransactions': FieldValue.increment(1),
        'stats.lastTransactionDate': now,
        'stats.${transactionType == 'send' ? 'totalSentAmount' : 'totalReceivedAmount'}':
            FieldValue.increment(_amount),
        'stats.totalCommission': FieldValue.increment(_commission),
        'updatedAt': now,
      };

      if (transactionType == 'send') {
        walletUpdate['sendLimits.dailyUsed'] = FieldValue.increment(_amount);
        walletUpdate['sendLimits.monthlyUsed'] = FieldValue.increment(_amount);
      } else {
        walletUpdate['receiveLimits.dailyUsed'] = FieldValue.increment(_amount);
        walletUpdate['receiveLimits.monthlyUsed'] =
            FieldValue.increment(_amount);
      }
      batch.update(walletRef, walletUpdate);

      // 3. Stats Summary Document
      final summaryRef = firestore
          .collection('stores')
          .doc(storeId)
          .collection('stats')
          .doc('summary');
      final summaryUpdate = <String, dynamic>{
        'totalTransactions': FieldValue.increment(1),
        'totalCommission': FieldValue.increment(_commission),
        'lastUpdated': now,
      };
      if (transactionType == 'send') {
        summaryUpdate['sendCount'] = FieldValue.increment(1);
        summaryUpdate['totalSentAmount'] = FieldValue.increment(_amount);
      } else {
        summaryUpdate['receiveCount'] = FieldValue.increment(1);
        summaryUpdate['totalReceivedAmount'] = FieldValue.increment(_amount);
      }
      batch.set(summaryRef, summaryUpdate, SetOptions(merge: true));

      // 4. Daily Stats Document
      final date = now.toDate();
      final todayDateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final dailyStatsRef = firestore
          .collection('stores')
          .doc(storeId)
          .collection('daily_stats')
          .doc(todayDateStr);
      batch.set(
        dailyStatsRef,
        {
          'transactionCount': FieldValue.increment(1),
          'totalCommission': FieldValue.increment(_commission),
          'totalAmount': FieldValue.increment(_amount),
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      // 5. Commit Batch
      await batch.commit();

      // 6. Send directly to Main App Isolate via Native Port
      final SendPort? sendPort =
          IsolateNameServer.lookupPortByName('overlay_tx_port');
      if (sendPort != null) {
        sendPort.send({
          'amount': _amount,
          'commission': _commission,
          'type': _type,
          'walletId': _selectedWalletId,
          'sender': _sender,
        });
        debugPrint(">>> Sent data via IsolateNameServer");
      } else {
        debugPrint(">>> Main App port not found (App might be closed)");
      }
      // 7. Close Overlay safely
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint(">>> OverlayProvider Error saving batch: $e");
      _errorMessage = 'Error saving: ${e.toString()}';
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
