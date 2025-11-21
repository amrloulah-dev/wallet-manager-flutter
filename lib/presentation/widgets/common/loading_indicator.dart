import 'package:flutter/material.dart';

enum LoadingStyle {
  circular,
  linear,
  dots,
}

class LoadingIndicator extends StatefulWidget {
  final String? message;
  final Color? color;
  final double size;
  final LoadingStyle style;

  const LoadingIndicator({
    super.key,
    this.message,
    this.color,
    this.size = 40,
    this.style = LoadingStyle.circular,
  });

  @override
  State<LoadingIndicator> createState() => _LoadingIndicatorState();
}

class _LoadingIndicatorState extends State<LoadingIndicator>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIndicator(),
            if (widget.message != null) ...[
              const SizedBox(height: 16),
              ScaleTransition(
                scale: _pulseAnimation,
                child: Text(
                  widget.message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: widget.color ?? Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    switch (widget.style) {
      case LoadingStyle.linear:
        return SizedBox(
          width: widget.size * 4,
          child: LinearProgressIndicator(
            color: widget.color,
            minHeight: 5,
            borderRadius: BorderRadius.circular(5),
          ),
        );
      case LoadingStyle.dots:
        return _buildDotsIndicator();
      case LoadingStyle.circular:
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: 3.0,
            color: widget.color,
          ),
        );
    }
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return ScaleTransition(
          scale: DelayTween(begin: 0.0, end: 1.0, delay: index * 0.2)
              .animate(_pulseController),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: CircleAvatar(
              radius: widget.size / 8,
              backgroundColor: widget.color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      }),
    );
  }
}

class DelayTween extends Tween<double> {
  final double delay;

  DelayTween({required double begin, required double end, required this.delay})
      : super(begin: begin, end: end);

  @override
  double lerp(double t) {
    return super.lerp((t - delay).clamp(0.0, 1.0));
  }
}