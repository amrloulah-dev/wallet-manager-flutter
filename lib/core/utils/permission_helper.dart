import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

import '../../data/models/user_permissions.dart';
import '../../providers/auth_provider.dart';
import '../constants/route_constants.dart';

class PermissionHelper {
  // Private constructor to prevent instantiation
  PermissionHelper._();

  static bool _checkPermission(
      BuildContext context, bool Function(UserPermissions) check,
      {bool showMessage = false}) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isOwner) {
      return true; // Owners have all permissions
    }
    final permissions = authProvider.currentUser?.permissions;
    if (permissions != null) {
      if (check(permissions)) {
        return true;
      }
    }
    if (showMessage) {
      ToastUtils.showError(AppLocalizations.of(context)!.accessDenied);
    }
    return false;
  }

  static bool canCreateTransactions(BuildContext context,
      {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.createTransaction,
        showMessage: showMessage);
  }

  static bool canCreateDebt(BuildContext context, {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.createDebt,
        showMessage: showMessage);
  }

  static bool canMarkDebtPaid(BuildContext context,
      {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.collectDebt,
        showMessage: showMessage);
  }

  static bool canViewAllTransactions(BuildContext context,
      {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.viewAllTransactions,
        showMessage: showMessage);
  }

  static bool canAccessScreen(BuildContext context, String routeName,
      {bool showMessage = false}) {
    final authProvider = context.read<AuthProvider>();
    
    // Core routes must not block authenticated owners and employees due to expired subscription/trial
    if (authProvider.isAuthenticated) {
      if (routeName == RouteConstants.mainDashboard ||
          routeName == RouteConstants.settings ||
          routeName == RouteConstants.upgradeScreen ||
          routeName == RouteConstants.licenseExpired ||
          routeName == RouteConstants.subscriptionDetails) {
        return true;
      }
    }

    return _checkPermission(context, (p) {
      switch (routeName) {
        case RouteConstants.mainDashboard:
          return true; // Basic dashboard usually accessible if logged in

        case RouteConstants.generalStatistics:
          return p.viewDashboardStats;

        case RouteConstants.createTransaction:
          return p.createTransaction;

        case RouteConstants.todayTransactions:
        case RouteConstants.transactionDetails:
          return p.createTransaction || p.viewAllTransactions;

        case RouteConstants.addDebt:
          return p.createDebt;

        case RouteConstants.debtsList:
          return p.viewDebts;

        case RouteConstants.walletsList:
        case RouteConstants.walletDetails:
          return p.viewWallets;

        case RouteConstants.walletForm:
          return p.createWallet || p.editWallet;

        case RouteConstants.addBalance:
          return p.addBalance;

        case RouteConstants.settings:
        case RouteConstants.subscriptionDetails:
          return true; // Basic settings usually allowed

        case RouteConstants.addEmployee:
        case RouteConstants.manageEmployees:
          // Employees cannot manage other employees
          return false;

        case RouteConstants.loginLanding:
        case RouteConstants.storeRegistration:
        case RouteConstants.employeeLogin:
          return true; // Auth routes always allowed

        default:
          return false; // Fail-closed for security on unknown routes
      }
    }, showMessage: showMessage);
  }
}
