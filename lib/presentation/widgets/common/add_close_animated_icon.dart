import 'package:flutter/material.dart';
import 'dart:math' as math;

class AddCloseAnimatedIcon extends StatelessWidget {
  final Animation<double> progress;
  final Color color;
  final double size;

  const AddCloseAnimatedIcon({
    super.key,
    required this.progress,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        return CustomPaint(
          size: Size(size, size),
          painter: _AddClosePainter(
            progress: progress.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _AddClosePainter extends CustomPainter {
  final double progress;
  final Color color;

  _AddClosePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width / 8
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final length = size.width / 2;

    // Define the two lines for the '+'
    final p1 = Offset(center.dx - length, center.dy);
    final p2 = Offset(center.dx + length, center.dy);
    final p3 = Offset(center.dx, center.dy - length);
    final p4 = Offset(center.dx, center.dy + length);

    // Save the canvas, translate to center, rotate, and translate back
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress * math.pi / 4); // Rotate by up to 45 degrees
    canvas.translate(-center.dx, -center.dy);

    // Draw the '+'
    canvas.drawLine(p1, p2, paint);
    canvas.drawLine(p3, p4, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AddClosePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
