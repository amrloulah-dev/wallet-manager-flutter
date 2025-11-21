import 'package:flutter/material.dart';
import 'package:walletmanager/core/theme/app_colors.dart';
import 'package:walletmanager/core/theme/app_text_styles.dart';

enum DialogType {
  info,
  success,
  warning,
  danger,
}

class DialogUtils {
  static Future<T?> _showAnimatedDialog<T>(
    BuildContext context, {
    required Widget child,
    required DialogType type,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeOut,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: curve,
            child: child,
          ),
        );
      },
    );
  }

  static Future<bool?> showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    DialogType type = DialogType.info,
  }) {
    return _showAnimatedDialog<bool>(
      context,
      type: type,
      child: _DialogContent(
        title: title,
        message: message,
        type: type,
        actions: [
          Expanded(
            child: TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: _getHeaderColor(type),
              ),
              child: Text(confirmText),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'حسناً',
  }) async {
    await _showAnimatedDialog(
      context,
      type: DialogType.info,
      child: _DialogContent(
        title: title,
        message: message,
        type: DialogType.info,
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'ممتاز!',
  }) async {
    await _showAnimatedDialog(
      context,
      type: DialogType.success,
      child: _DialogContent(
        title: title,
        message: message,
        type: DialogType.success,
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> showWarningDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'موافق',
  }) async {
    await _showAnimatedDialog(
      context,
      type: DialogType.warning,
      child: _DialogContent(
        title: title,
        message: message,
        type: DialogType.warning,
        actions: [
          Expanded(
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }

  static Future<T?> showOptionsDialog<T>(
    BuildContext context, {
    required String title,
    required List<Widget> options,
  }) {
    return _showAnimatedDialog<T>(
      context,
      type: DialogType.info,
      child: _DialogContent(
        title: title,
        type: DialogType.info,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options,
          ),
        ),
      ),
    );
  }

  static Color _getHeaderColor(DialogType type) {
    switch (type) {
      case DialogType.info:
        return AppColors.info;
      case DialogType.success:
        return AppColors.success;
      case DialogType.warning:
        return AppColors.warning;
      case DialogType.danger:
        return AppColors.error;
    }
  }
}

class _DialogContent extends StatelessWidget {
  final String title;
  final String? message;
  final Widget? content;
  final List<Widget>? actions;
  final DialogType type;

  const _DialogContent({
    required this.title,
    this.message,
    this.content,
    this.actions,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 40),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTextStyles.h2.copyWith(color: Colors.black),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              content ??
                  Text(
                    message ?? '',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
        _DialogHeader(type: type),
      ],
    );
  }
}

class _DialogHeader extends StatefulWidget {
  final DialogType type;

  const _DialogHeader({required this.type});

  @override
  State<_DialogHeader> createState() => _DialogHeaderState();
}

class _DialogHeaderState extends State<_DialogHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIconForType(DialogType type) {
    switch (type) {
      case DialogType.info:
        return Icons.info_outline;
      case DialogType.success:
        return Icons.check_circle_outline;
      case DialogType.warning:
        return Icons.warning_amber_outlined;
      case DialogType.danger:
        return Icons.dangerous_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = DialogUtils._getHeaderColor(widget.type);
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: Theme.of(context).cardColor,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: Color.fromARGB((0.15 * 255).round(), 0, 0, 0),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(
          _getIconForType(widget.type),
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }
}