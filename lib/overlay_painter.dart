// overlay_painter.dart
import 'package:flutter/material.dart';

class OverlayPainter extends CustomPainter {
  final Offset? laserPosition;
  final bool isBlocked;

  OverlayPainter({this.laserPosition, this.isBlocked = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (laserPosition != null) {
      if (isBlocked) {
        // Draw cross
        final paint = Paint()
          ..color = Colors.red
          ..strokeWidth = 4;
        canvas.drawLine(laserPosition! - const Offset(20, 20), laserPosition! + const Offset(20, 20), paint);
        canvas.drawLine(laserPosition! - const Offset(20, -20), laserPosition! + const Offset(20, -20), paint);
      } else {
        // Draw circle
        final paint = Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        canvas.drawCircle(laserPosition!, 24, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter oldDelegate) {
    return oldDelegate.laserPosition != laserPosition || oldDelegate.isBlocked != isBlocked;
  }
}
