import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';

class PermissionHelper {
  // Private constructor to prevent instantiation
  PermissionHelper._();

  static bool _checkPermission(BuildContext context, bool Function(UserPermissions) check, {bool showMessage = false}) {
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
      ToastUtils.showError('ليس لديك الصلاحية للقيام بهذا الإجراء');
    }
    return false;
  }

  static bool canCreateTransactions(BuildContext context, {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.canCreateTransactions, showMessage: showMessage);
  }

  static bool canCreateDebt(BuildContext context, {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.canCreateDebt, showMessage: showMessage);
  }

  static bool canMarkDebtPaid(BuildContext context, {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.canMarkDebtPaid, showMessage: showMessage);
  }

  static bool canViewAllTransactions(BuildContext context, {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.canViewAllTransactions, showMessage: showMessage);
  }

  static bool canAccessScreen(BuildContext context, String screenName, {bool showMessage = false}) {
    return _checkPermission(context, (p) => p.canAccessScreens.contains(screenName), showMessage: showMessage);
  }
}
