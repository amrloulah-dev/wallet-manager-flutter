import 'package:walletmanager/data/services/firebase_service.dart';
import 'package:walletmanager/data/models/transaction_model.dart';
import 'package:walletmanager/data/repositories/transaction_repository.dart';
import 'package:walletmanager/data/services/local_storage_service.dart';
import 'package:walletmanager/core/utils/fee_calculator.dart';
import 'package:walletmanager/core/enums/transaction_enums.dart';
import 'package:walletmanager/core/enums/wallet_enums.dart';
import 'package:walletmanager/core/di/service_locator.dart';
import 'package:walletmanager/providers/platform_settings_provider.dart';

class TransactionResult {
  final String txId;
  final double totalDeduction;
  final bool isSend;

  TransactionResult({
    required this.txId,
    required this.totalDeduction,
    required this.isSend,
  });
}

class OverlayUseCase {
  final TransactionRepository _transactionRepository;
  final LocalStorageService _localStorage;

  OverlayUseCase({
    required TransactionRepository transactionRepository,
    required LocalStorageService localStorage,
  })  : _transactionRepository = transactionRepository,
        _localStorage = localStorage;

  Future<TransactionResult> execute({
    required String storeId,
    required String userId,
    required String? userName,
    required String? userRole,
    required String selectedWalletId,
    required String type,
    required double amount,
    required double commission,
    required String sender,
    required List<Map<String, dynamic>> availableWallets,
  }) async {
    if (!FirebaseService().isInitialized) {
      await FirebaseService().initialize();
    }

    TransactionType transactionType = type == 'debit'
        ? TransactionType.debit
        : TransactionType.credit; // ENUM refactor
    final now = DateTime.now();
    final txId = _transactionRepository.generateId();

    final match = availableWallets.cast<Map<String, dynamic>?>().firstWhere(
          (w) => w?['id'] == selectedWalletId,
          orElse: () => null,
        );
    if (match != null && match['isFrozen'] == true) {
      throw Exception('wallet_is_frozen');
    }
    final rawWalletType = match?['walletType']?.toString() ?? 'vodafone_cash';
    final walletType = WalletType.fromString(rawWalletType);

    final settings = sl<PlatformSettingsProvider>().settings;
    double calculatedServiceFee = 0.0;
    if (transactionType == TransactionType.debit) {
      calculatedServiceFee = FeeCalculator.calculateTransactionFee(
        amount: amount,
        sourceWalletType: walletType.dbValue,
        receiverPhone: sender,
        settings: settings,
      );
    }

    final newTransaction = TransactionModel(
      transactionId: txId,
      storeId: storeId,
      walletId: selectedWalletId,
      transactionType: transactionType,
      customerPhone: sender,
      amount: amount,
      commission: commission,
      serviceFee: calculatedServiceFee,
      paymentStatus: PaymentStatus.paid, // ENUM refactor
      transactionDate: now,
      createdAt: now,
      createdBy: userName ?? 'SMS Auto',
      createdById: userId,
      createdByName: userName,
      creatorRole: userRole,
      isDeleted: false,
      notes: 'Automated via SMS',
    );

    await _transactionRepository.createTransaction(newTransaction);

    final totalDeductionForVault =
        newTransaction.amount + newTransaction.serviceFee;

    final txData = {
      'transactionId': txId,
      'amount': newTransaction.amount,
      'serviceFee': newTransaction.serviceFee,
      'totalDeduction': totalDeductionForVault,
      'commission': commission,
      'type': type,
      'walletId': selectedWalletId,
      'sender': sender,
      'transactionDate': now.toIso8601String(),
      'storeId': storeId,
      'paymentStatus': PaymentStatus.paid.name, // ENUM refactor
      'customerName': '',
      'blockAutoFetch': true,
    };

    // Isolated IPC sync storage via LocalStorageService
    await _localStorage.saveCompletedTxSync(txData);

    return TransactionResult(
      txId: txId,
      totalDeduction: totalDeductionForVault,
      isSend: newTransaction.isSend,
    );
  }
}
