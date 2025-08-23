import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class TinyPointDetectorConfig {
  int brightnessThreshold;
  int clusterRadius;
  int minClusterPixels;
  bool colorFilterEnabled;
  int hMin, hMax, sMin, sMax, vMin, vMax;

  TinyPointDetectorConfig({
    this.brightnessThreshold = 220,
    this.clusterRadius = 4,
    this.minClusterPixels = 3,
    this.colorFilterEnabled = false,
    this.hMin = 0,
    this.hMax = 255,
    this.sMin = 0,
    this.sMax = 255,
    this.vMin = 200,
    this.vMax = 255,
  });
}

class TinyPointDetector {
  final ValueNotifier<List<String>> logNotifier;
  TinyPointDetectorConfig config;

  TinyPointDetector(this.logNotifier, this.config);

  Offset? detect(CameraImage image, int frameNumber) {
    final width = image.width;
    final height = image.height;
    List<_BrightPixel> candidates = [];
    int brightestValue = 0;
    // Step 1: Find bright pixels
    for (int y = 0; y < height; y += 2) {
      for (int x = 0; x < width; x += 2) {
        int Y = _getY(image, x, y);
        if (Y > config.brightnessThreshold) {
          if (config.colorFilterEnabled) {
            final hsv = _getHSV(image, x, y);
            if (!_hsvInRange(hsv)) continue;
          }
          candidates.add(_BrightPixel(x, y, Y));
          if (Y > brightestValue) brightestValue = Y;
        }
      }
    }
    // Step 2: Cluster bright pixels
    List<List<_BrightPixel>> clusters = _clusterPixels(candidates, config.clusterRadius);
    // Step 3: Find brightest cluster
    List<_BrightPixel>? brightestCluster;
    int maxBrightness = 0;
    for (final cluster in clusters) {
      if (cluster.length < config.minClusterPixels) continue;
      int sumBrightness = cluster.fold(0, (sum, p) => sum + p.brightness);
      if (sumBrightness > maxBrightness) {
        maxBrightness = sumBrightness;
        brightestCluster = cluster;
      }
    }
    // Step 4: Output centroid
    Offset? centroid;
    if (brightestCluster != null) {
      double sumX = 0, sumY = 0;
      for (final p in brightestCluster) {
        sumX += p.x;
        sumY += p.y;
      }
      centroid = Offset(sumX / brightestCluster.length, sumY / brightestCluster.length);
    }
    // Logging
    _log('Frame $frameNumber | Mode: TinyPoint | Candidates: ${candidates.length} | Clusters: ${clusters.length} | Brightest: $brightestValue | Chosen: $centroid');
    _trimLogs();
    return centroid;
  }

  int _getY(CameraImage image, int x, int y) {
    if (image.format.group == ImageFormatGroup.yuv420) {
      final yp = y * image.width + x;
      return image.planes[0].bytes[yp];
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      final i = (y * image.width + x) * 4;
      int r = image.planes[0].bytes[i + 2];
      int g = image.planes[0].bytes[i + 1];
      int b = image.planes[0].bytes[i];
      return (0.299 * r + 0.587 * g + 0.114 * b).toInt();
    }
    return 0;
  }

  List<int> _getHSV(CameraImage image, int x, int y) {
    int r = 0, g = 0, b = 0;
    if (image.format.group == ImageFormatGroup.bgra8888) {
      final i = (y * image.width + x) * 4;
      b = image.planes[0].bytes[i];
      g = image.planes[0].bytes[i + 1];
      r = image.planes[0].bytes[i + 2];
    } else if (image.format.group == ImageFormatGroup.yuv420) {
      final yp = y * image.width + x;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      final up = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
      final vp = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
      int Y = image.planes[0].bytes[yp];
      int U = image.planes[1].bytes[up];
      int V = image.planes[2].bytes[vp];
      r = (Y + 1.402 * (V - 128)).clamp(0, 255).toInt();
      g = (Y - 0.344136 * (U - 128) - 0.714136 * (V - 128)).clamp(0, 255).toInt();
      b = (Y + 1.772 * (U - 128)).clamp(0, 255).toInt();
    }
    return _rgbToHsv(r, g, b);
  }

  bool _hsvInRange(List<int> hsv) {
    return hsv[0] >= config.hMin && hsv[0] <= config.hMax &&
           hsv[1] >= config.sMin && hsv[1] <= config.sMax &&
           hsv[2] >= config.vMin && hsv[2] <= config.vMax;
  }

  List<int> _rgbToHsv(int r, int g, int b) {
    double rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
    double max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
    double min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
    double h = 0, s = 0, v = max;
    double d = max - min;
    if (max != min) {
      if (max == rf) {
        h = (gf - bf) / d + (gf < bf ? 6 : 0);
      } else if (max == gf) {
        h = (bf - rf) / d + 2;
      } else {
        h = (rf - gf) / d + 4;
      }
      h /= 6;
    }
    if (max != 0) s = d / max;
    return [(h * 255).toInt(), (s * 255).toInt(), (v * 255).toInt()];
  }

  List<List<_BrightPixel>> _clusterPixels(List<_BrightPixel> pixels, int radius) {
    List<List<_BrightPixel>> clusters = [];
    for (final pt in pixels) {
      bool added = false;
      for (final cluster in clusters) {
        for (final cpt in cluster) {
          if ((Offset(pt.x.toDouble(), pt.y.toDouble()) - Offset(cpt.x.toDouble(), cpt.y.toDouble())).distance < radius) {
            cluster.add(pt);
            added = true;
            break;
          }
        }
        if (added) break;
      }
      if (!added) clusters.add([pt]);
    }
    return clusters;
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

class _BrightPixel {
  final int x, y, brightness;
  _BrightPixel(this.x, this.y, this.brightness);
}
