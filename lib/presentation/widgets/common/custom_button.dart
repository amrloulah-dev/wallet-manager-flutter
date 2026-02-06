import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

enum ButtonType { primary, secondary, outlined, text }

enum ButtonSize { large, medium, small }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonType type;
  final ButtonSize size;
  final Widget? icon;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.fullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = _getButtonStyle(context);
    final buttonContent = _buildContent();

    Widget button;
    switch (widget.type) {
      case ButtonType.primary:
      case ButtonType.secondary:
        button = ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: buttonStyle,
          child: buttonContent,
        );
        break;
      case ButtonType.outlined:
        button = OutlinedButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: buttonStyle,
          child: buttonContent,
        );
        break;
      case ButtonType.text:
        button = TextButton(
          onPressed: widget.isLoading ? null : widget.onPressed,
          style: buttonStyle,
          child: buttonContent,
        );
        break;
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.fullWidth
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return SizedBox(
        height: _getFontSize(),
        width: _getFontSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            widget.textColor ??
                (widget.type == ButtonType.primary
                    ? Colors.white
                    : AppColors.primary),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          widget.icon!,
          const SizedBox(width: 8),
        ],
        Text(widget.text, style: _getTextStyle()),
      ],
    );
  }

  ButtonStyle _getButtonStyle(BuildContext context) {
    final effectiveBackgroundColor =
        widget.backgroundColor ?? _getBackgroundColor();
    final effectiveTextColor = widget.textColor ?? _getTextColor();
    final effectiveBorderRadius = widget.borderRadius ?? 12;
    final effectivePadding = _getPadding();

    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return effectiveBackgroundColor.withAlpha((0.5 * 255).round());
        }
        return effectiveBackgroundColor;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.disabled)) {
          return effectiveTextColor.withAlpha((0.7 * 255).round());
        }
        return effectiveTextColor;
      }),
      overlayColor: WidgetStateProperty.all(
          effectiveTextColor.withAlpha((0.1 * 255).round())),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(effectiveBorderRadius),
        ),
      ),
      side: widget.type == ButtonType.outlined
          ? WidgetStateProperty.all(
              BorderSide(color: effectiveBackgroundColor, width: 1.5),
            )
          : null,
      padding: WidgetStateProperty.all(effectivePadding),
      textStyle: WidgetStateProperty.all(_getTextStyle()),
      elevation: WidgetStateProperty.all(widget.type == ButtonType.primary ||
              widget.type == ButtonType.secondary
          ? 2
          : 0),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case ButtonType.primary:
        return AppColors.primary;
      case ButtonType.secondary:
        return AppColors.primary; // Example for secondary
      case ButtonType.outlined:
      case ButtonType.text:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    switch (widget.type) {
      case ButtonType.primary:
        return Colors.white;
      case ButtonType.secondary:
        return Colors.white;
      case ButtonType.outlined:
      case ButtonType.text:
        return AppColors.primary;
    }
  }

  TextStyle _getTextStyle() {
    final fontSize = _getFontSize();
    switch (widget.size) {
      case ButtonSize.large:
        return AppTextStyles.buttonLarge.copyWith(
            fontSize: fontSize, color: widget.textColor ?? _getTextColor());
      case ButtonSize.medium:
        return AppTextStyles.buttonMedium.copyWith(
            fontSize: fontSize, color: widget.textColor ?? _getTextColor());
      case ButtonSize.small:
        return AppTextStyles.buttonSmall.copyWith(
            fontSize: fontSize, color: widget.textColor ?? _getTextColor());
    }
  }

  double _getFontSize() {
    switch (widget.size) {
      case ButtonSize.large:
        return 18;
      case ButtonSize.medium:
        return 16;
      case ButtonSize.small:
        return 14;
    }
  }

  EdgeInsetsGeometry _getPadding() {
    switch (widget.size) {
      case ButtonSize.large:
        return const EdgeInsets.symmetric(vertical: 18, horizontal: 32);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(vertical: 14, horizontal: 24);
      case ButtonSize.small:
        return const EdgeInsets.symmetric(vertical: 10, horizontal: 16);
    }
  }
}
