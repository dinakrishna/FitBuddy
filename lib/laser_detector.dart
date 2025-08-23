// laser_detector.dart
// Placeholder for laser point detection logic
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class LaserDetectorResult {
  final Offset? laserPosition;
  final bool isBlocked;
  LaserDetectorResult({this.laserPosition, this.isBlocked = false});
}

class LaserDetector {
  final ValueNotifier<List<String>> logNotifier;

  LaserDetector(this.logNotifier);

  /// Returns a list of detected red blob centers (Offset), or empty if none found.
  List<Offset> detectBlobsByColor(CameraImage image, int frameNumber, Color color, {int pixelStep = 2, int minBlobSize = 5}) {
    // Convert color to RGB
    int targetR = color.red, targetG = color.green, targetB = color.blue;
    if (image.format.group != ImageFormatGroup.yuv420 && image.format.group != ImageFormatGroup.bgra8888) {
      _log('Frame $frameNumber: Unsupported format');
      return [];
    }
    final width = image.width;
    final height = image.height;
    // Step 1: Collect all candidate red pixels
    List<Offset> candidates = [];
    for (int y = 0; y < height; y += pixelStep) {
      for (int x = 0; x < width; x += pixelStep) {
        int r = 0, g = 0, b = 0;
        if (image.format.group == ImageFormatGroup.bgra8888) {
          final i = (y * width + x) * 4;
          b = image.planes[0].bytes[i];
          g = image.planes[0].bytes[i + 1];
          r = image.planes[0].bytes[i + 2];
        } else if (image.format.group == ImageFormatGroup.yuv420) {
          final uvRowStride = image.planes[1].bytesPerRow;
          final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
          final yp = y * width + x;
          final up = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          final vp = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          int Y = image.planes[0].bytes[yp];
          int U = image.planes[1].bytes[up];
          int V = image.planes[2].bytes[vp];
          r = (Y + 1.402 * (V - 128)).clamp(0, 255).toInt();
          g = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).clamp(0, 255).toInt();
          b = (Y + 1.772 * (U - 128)).clamp(0, 255).toInt();
        }
        // Color distance threshold
        double dist = ((r - targetR) * (r - targetR) + (g - targetG) * (g - targetG) + (b - targetB) * (b - targetB)).toDouble();
        if (dist < 4000) {
          candidates.add(Offset(x.toDouble(), y.toDouble()));
        }
      }
    }
    // Step 2: Simple blob detection (group nearby candidates)
    List<List<Offset>> blobs = [];
    double distThresh = 20.0; // pixels
    for (final pt in candidates) {
      bool added = false;
      for (final blob in blobs) {
        for (final bpt in blob) {
          if ((pt - bpt).distance < distThresh) {
            blob.add(pt);
            added = true;
            break;
          }
        }
        if (added) break;
      }
      if (!added) blobs.add([pt]);
    }
    // Step 3: Calculate centroid for each blob
    List<Offset> centers = [];
    for (final blob in blobs) {
      if (blob.length < minBlobSize) continue; // ignore tiny blobs
      double sumX = 0, sumY = 0;
      for (final pt in blob) {
        sumX += pt.dx;
        sumY += pt.dy;
      }
      centers.add(Offset(sumX / blob.length, sumY / blob.length));
    }
  _log('Frame $frameNumber | Blobs found: ${centers.length} | pixelStep: $pixelStep | minBlobSize: $minBlobSize');
    _trimLogs();
    return centers;
  }
  void _log(String msg) {
    final logs = logNotifier.value;
    logs.add(msg);
    logNotifier.value = List<String>.from(logs);
  }

  void _trimLogs() {
    final logs = logNotifier.value;
    if (logs.length > 30) {
      logNotifier.value = logs.sublist(logs.length - 30);
    }
  }
}
