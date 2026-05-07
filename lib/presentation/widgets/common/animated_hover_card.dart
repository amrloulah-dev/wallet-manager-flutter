import 'package:flutter/material.dart';

class AnimatedHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double initialElevation;
  final double highlightedElevation;
  final double scale;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;

  const AnimatedHoverCard({
    super.key,
    required this.child,
    required this.onTap,
    this.initialElevation = 2.0,
    this.highlightedElevation = 8.0,
    this.scale = 0.98,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard> {
  bool _isHighlighted = false;

  @override
  Widget build(BuildContext context) {
    final elevation =
        _isHighlighted ? widget.highlightedElevation : widget.initialElevation;
    final currentScale = _isHighlighted ? widget.scale : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.diagonal3Values(currentScale, currentScale, 1.0),
      child: Card(
        elevation: elevation,
        margin: widget.margin,
        shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (isHighlighted) {
            setState(() {
              _isHighlighted = isHighlighted;
            });
          },
          borderRadius: widget.borderRadius,
          child: widget.child,
        ),
      ),
    );
  }
}
