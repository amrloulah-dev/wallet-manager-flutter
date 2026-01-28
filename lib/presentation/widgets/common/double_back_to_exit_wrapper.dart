import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:walletmanager/core/utils/toast_utils.dart';

class DoubleBackToExitWrapper extends StatefulWidget {
  final Widget child;

  const DoubleBackToExitWrapper({super.key, required this.child});

  @override
  State<DoubleBackToExitWrapper> createState() =>
      _DoubleBackToExitWrapperState();
}

class _DoubleBackToExitWrapperState extends State<DoubleBackToExitWrapper> {
  DateTime? _lastPressedTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final now = DateTime.now();
        final showExitWarning = _lastPressedTime == null ||
            now.difference(_lastPressedTime!) > const Duration(seconds: 2);

        if (showExitWarning) {
          setState(() {
            _lastPressedTime = now;
          });
          ToastUtils.showInfo('اضغط مرة أخرى للخروج');
        } else {
          await SystemNavigator.pop();
        }
      },
      child: widget.child,
    );
  }
}
