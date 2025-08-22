// overlay_painter.dart
import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  final List<Offset> laserPositions;
  final bool isBlocked;

  OverlayPainter({required this.laserPositions, this.isBlocked = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isBlocked ? Colors.red : Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (final pos in laserPositions) {
      canvas.drawCircle(pos, 24, paint);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.laserPositions != laserPositions || oldDelegate.isBlocked != isBlocked;
  }
}
