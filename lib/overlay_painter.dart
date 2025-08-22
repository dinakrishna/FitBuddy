// overlay_painter.dart
import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  final List<Offset> laserPositions;
  final bool isBlocked;
  final Color color;

  OverlayPainter({required this.laserPositions, this.isBlocked = false, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (final pos in laserPositions) {
      canvas.drawCircle(pos, 24, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.laserPositions != laserPositions || oldDelegate.isBlocked != isBlocked || oldDelegate.color != color;
  }
}
