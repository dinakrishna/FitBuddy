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

  Offset? detectLaser(CameraImage image, int frameNumber) {
    int maxBrightness = 0;
    int? laserX;
    int? laserY;
    int totalBrightness = 0;
    int pixelCount = 0;
    List<String> candidatePixels = [];
    int brightestR = 0, brightestG = 0, brightestB = 0;

    if (image.format.group != ImageFormatGroup.yuv420 && image.format.group != ImageFormatGroup.bgra8888) {
      _log('Frame $frameNumber: Unsupported format');
      return null;
    }

    final width = image.width;
    final height = image.height;

    for (int y = 0; y < height; y += 4) {
      for (int x = 0; x < width; x += 4) {
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
        int brightness = r;
        totalBrightness += (r + g + b) ~/ 3;
        pixelCount++;
        if (r > 180 && r > g + 60 && r > b + 60) {
          candidatePixels.add('($x,$y) R:$r G:$g B:$b');
          if (brightness > maxBrightness) {
            maxBrightness = brightness;
            laserX = x;
            laserY = y;
            brightestR = r;
            brightestG = g;
            brightestB = b;
          }
        }
      }
    }
    double avgBrightness = pixelCount > 0 ? totalBrightness / pixelCount : 0;
    if (laserX != null && laserY != null) {
      _log('Frame $frameNumber | Avg: ${avgBrightness.toStringAsFixed(1)} | Candidates: ${candidatePixels.length}');
      _log('Brightest: ($laserX,$laserY) R:$brightestR G:$brightestG B:$brightestB | Brightness: $maxBrightness | RedRatio: ${brightestR / ((brightestG + brightestB + 1) / 2)}');
      if (candidatePixels.isNotEmpty) {
        _log('Candidates: ${candidatePixels.take(5).join(' | ')}${candidatePixels.length > 5 ? ' ...' : ''}');
      }
      _trimLogs();
      return Offset(laserX.toDouble(), laserY.toDouble());
    } else {
      _log('Frame $frameNumber | Avg: ${avgBrightness.toStringAsFixed(1)} | No pixel above threshold | Max brightness: $maxBrightness');
      _trimLogs();
      return null;
    }
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
