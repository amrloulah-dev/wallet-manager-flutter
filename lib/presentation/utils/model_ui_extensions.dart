import 'package:flutter/material.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_helper.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/debt_model.dart';

extension TransactionModelUI on TransactionModel {
  String getTransactionTypeDisplay(AppLocalizations l10n) {
    if (isSend) return l10n.send;
    if (isReceive) return l10n.receive;
    if (isDeposit) return l10n.deposit;
    return transactionType.name; // ENUM refactor
  }

  IconData get transactionTypeIcon => isSend
      ? Icons.arrow_upward
      : (isReceive ? Icons.arrow_downward : Icons.add_card_outlined);
      
  Color get transactionTypeColor => isSend
      ? AppColors.send
      : (isReceive ? AppColors.receive : AppColors.primary);

  String getPaymentStatusDisplay(AppLocalizations l10n) {
    return isPaid ? l10n.paid : l10n.debt;
  }

  String getRelativeTime(AppLocalizations l10n) =>
      DateHelper.getRelativeTime(transactionDate ?? DateTime.now(), l10n: l10n); // Safe access

  bool get canBeModified {
    // Can be modified within 5 minutes of creation
    return DateTime.now().difference(createdAt ?? DateTime.now()).inMinutes < 5; // Safe access
  }

  String get formattedDate =>
      DateHelper.formatDateTime(transactionDate ?? DateTime.now(), format: 'dd/MM/yyyy'); // Safe access
  String get formattedTime =>
      DateHelper.formatDateTime(transactionDate ?? DateTime.now(), format: 'hh:mm a'); // Safe access
}

extension DebtModelUI on DebtModel {
  String getDebtTypeDisplay(AppLocalizations l10n) =>
      isTransactionDebt ? l10n.walletTransaction : l10n.storeSale;
  
  String getDebtStatusDisplay(AppLocalizations l10n) => 
      isOpen ? l10n.openDebt : l10n.paidDebt;

  IconData get debtTypeIcon =>
      isTransactionDebt ? Icons.swap_horiz : Icons.shopping_cart;

  Color get statusColor => isOpen ? AppColors.error : AppColors.success;

  String getRelativeDebtDate(AppLocalizations l10n) => 
      DateHelper.getRelativeTime(debtDate ?? DateTime.now(), l10n: l10n); // Safe access

  int get daysSinceCreated =>
      DateTime.now().difference(debtDate ?? DateTime.now()).inDays; // Safe access
  
  String get formattedDebtDate => DateHelper.formatDateTime(debtDate ?? DateTime.now()); // Safe access
  
  String get formattedPaidDate =>
      paidDate != null ? DateHelper.formatDateTime(paidDate!) : '';
}
