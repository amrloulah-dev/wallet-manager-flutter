import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'custom_button.dart';

class EmptyStateWidget extends StatefulWidget {
  final String message;
  final String? description;
  final IconData? icon;
  final Widget? illustration;
  final String? actionText;
  final VoidCallback? onAction;
  final bool animate;

  const EmptyStateWidget({
    super.key,
    required this.message,
    this.description,
    this.icon,
    this.illustration,
    this.actionText,
    this.onAction,
    this.animate = true,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconFade, _iconScale;
  late final Animation<double> _titleFade;
  late final Animation<double> _descriptionFade;
  late final Animation<double> _buttonFade;
  late final Animation<Offset> _buttonSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _iconFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _descriptionFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOut),
      ),
    );

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _buttonSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    if (widget.animate) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildIllustration(context),
              const SizedBox(height: 24),
              _buildTitle(),
              if (widget.description != null) _buildDescription(),
              if (widget.actionText != null && widget.onAction != null)
                _buildActionButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(BuildContext context) {
    final illustration = widget.illustration ??
        Icon(
          widget.icon ?? Icons.inbox_outlined,
          size: 80,
          color:
              AppColors.textSecondary(context).withAlpha((0.5 * 255).round()),
        );

    if (!widget.animate) {
      return illustration;
    }

    return ScaleTransition(
      scale: _iconScale,
      child: FadeTransition(
        opacity: _iconFade,
        child: illustration,
      ),
    );
  }

  Widget _buildTitle() {
    final titleWidget = Text(
      widget.message,
      style: AppTextStyles.h3,
      textAlign: TextAlign.center,
    );

    if (!widget.animate) {
      return titleWidget;
    }

    return FadeTransition(
      opacity: _titleFade,
      child: titleWidget,
    );
  }

  Widget _buildDescription() {
    final descriptionWidget = Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Text(
        widget.description!,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textSecondary(context),
        ),
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );

    if (!widget.animate) {
      return descriptionWidget;
    }

    return FadeTransition(
      opacity: _descriptionFade,
      child: descriptionWidget,
    );
  }

  Widget _buildActionButton() {
    final buttonWidget = Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: CustomButton(
        text: widget.actionText!,
        onPressed: widget.onAction,
        type: ButtonType.primary,
        size: ButtonSize.medium,
        fullWidth: false,
      ),
    );

    if (!widget.animate) {
      return buttonWidget;
    }

    return SlideTransition(
      position: _buttonSlide,
      child: FadeTransition(
        opacity: _buttonFade,
        child: buttonWidget,
      ),
    );
  }
}
