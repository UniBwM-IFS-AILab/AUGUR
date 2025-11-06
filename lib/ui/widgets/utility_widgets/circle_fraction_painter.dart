import 'dart:math';
import 'package:flutter/material.dart';

class CircleFractionPainter extends CustomPainter {
  final double angleCovered;

  CircleFractionPainter(this.angleCovered);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 255, 255, 255).withAlpha(153)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw only the portion of the circle corresponding to the angleCovered
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start at 12 o'clock position
      angleCovered, // Sweep angle based on number of platforms
      true,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
