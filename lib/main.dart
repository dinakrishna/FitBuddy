import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'laser_detector.dart';
import 'overlay_painter.dart';
import 'game_logic.dart';
import 'package:flutter/services.dart';
import 'tiny_point_detector.dart';

enum DetectionMode { blob, tinyPoint }

class DetectionManager {
  final LaserDetector blobDetector;
  final TinyPointDetector tinyPointDetector;
  DetectionMode mode;

  DetectionManager({
    required this.blobDetector,
    required this.tinyPointDetector,
    this.mode = DetectionMode.blob,
  });

  Offset? detect(CameraImage image, int frameNumber, Color selectedColor, {
    int pixelStep = 2,
    int minBlobSize = 5,
  }) {
    if (mode == DetectionMode.blob) {
      final blobs = blobDetector.detectBlobsByColor(
        image,
        frameNumber,
        selectedColor,
        pixelStep: pixelStep,
        minBlobSize: minBlobSize,
      );
      return blobs.isNotEmpty ? blobs.first : null;
    } else {
      return tinyPointDetector.detect(image, frameNumber);
    }
  }
}

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitBuddy Laser Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CameraGameScreen(),
    );
  }
}

class CameraGameScreen extends StatefulWidget {
  const CameraGameScreen({super.key});

  @override
  State<CameraGameScreen> createState() => _CameraGameScreenState();
}

class _CameraGameScreenState extends State<CameraGameScreen> {
  ResolutionPreset _selectedPreset = ResolutionPreset.high;
  final Map<String, ResolutionPreset> _presetMap = {
    'Low': ResolutionPreset.low,
    'Medium': ResolutionPreset.medium,
    'High': ResolutionPreset.high,
    'Very High': ResolutionPreset.veryHigh,
    'Ultra High': ResolutionPreset.ultraHigh,
    'Max': ResolutionPreset.max,
  };

  Future<void> _restartCamera(ResolutionPreset preset) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    setState(() {
      _controller = null;
    });
    _controller = CameraController(
      cameras[0],
      preset,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});
    _controller!.startImageStream(_processCameraImage);
  }
  Color _selectedColor = Colors.red;
  CameraController? _controller;
  late LaserDetector _laserDetector;
  late TinyPointDetector _tinyPointDetector;
  late DetectionManager _detectionManager;
  GameLogic _gameLogic = GameLogic();
  List<Offset> _laserPositions = [];
  bool _isBlocked = false;
  bool _isProcessingFrame = false;
  int _frameCount = 0;
  final ValueNotifier<List<String>> _logNotifier = ValueNotifier([]);
  int _pixelStep = 2;
  int _minBlobSize = 5;
  DetectionMode _detectionMode = DetectionMode.blob;

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = _selectedColor;
        int tempPixelStep = _pixelStep;
        int tempMinBlobSize = _minBlobSize;
        // TinyPointDetector config
        TinyPointDetectorConfig tempTinyConfig = TinyPointDetectorConfig(
          brightnessThreshold: _tinyPointDetector.config.brightnessThreshold,
          clusterRadius: _tinyPointDetector.config.clusterRadius,
          minClusterPixels: _tinyPointDetector.config.minClusterPixels,
          colorFilterEnabled: _tinyPointDetector.config.colorFilterEnabled,
          hMin: _tinyPointDetector.config.hMin,
          hMax: _tinyPointDetector.config.hMax,
          sMin: _tinyPointDetector.config.sMin,
          sMax: _tinyPointDetector.config.sMax,
          vMin: _tinyPointDetector.config.vMin,
          vMax: _tinyPointDetector.config.vMax,
        );
        final media = MediaQuery.of(context);
        final double dialogHeight = media.size.height * 0.9;
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: dialogHeight,
            ),
            child: AlertDialog(
              title: const Text('Pick Laser Color & Detection Tuning'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              content: StatefulBuilder(
                builder: (context, setStateDialog) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 800, minWidth: 400),
                            child: ColorPicker(
                              pickerColor: tempColor,
                              onColorChanged: (color) {
                                setStateDialog(() {
                                  tempColor = color;
                                });
                              },
                              showLabel: true,
                              pickerAreaHeightPercent: 0.8,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_detectionMode == DetectionMode.blob) ...[
                            Text('Pixel Step (lower = more accurate, higher = faster): $tempPixelStep'),
                            Slider(
                              min: 1,
                              max: 8,
                              divisions: 7,
                              value: tempPixelStep.toDouble(),
                              label: tempPixelStep.toString(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  tempPixelStep = v.round();
                                });
                              },
                            ),
                            Text('Min Blob Size (lower = detects smaller spots): $tempMinBlobSize'),
                            Slider(
                              min: 1,
                              max: 20,
                              divisions: 19,
                              value: tempMinBlobSize.toDouble(),
                              label: tempMinBlobSize.toString(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  tempMinBlobSize = v.round();
                                });
                              },
                            ),
                          ] else ...[
                            Text('Brightness Threshold: ${tempTinyConfig.brightnessThreshold}'),
                            Slider(
                              min: 100,
                              max: 255,
                              divisions: 31,
                              value: tempTinyConfig.brightnessThreshold.toDouble(),
                              label: tempTinyConfig.brightnessThreshold.toString(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  tempTinyConfig.brightnessThreshold = v.round();
                                });
                              },
                            ),
                            Text('Cluster Radius: ${tempTinyConfig.clusterRadius}'),
                            Slider(
                              min: 2,
                              max: 10,
                              divisions: 8,
                              value: tempTinyConfig.clusterRadius.toDouble(),
                              label: tempTinyConfig.clusterRadius.toString(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  tempTinyConfig.clusterRadius = v.round();
                                });
                              },
                            ),
                            Text('Min Cluster Pixels: ${tempTinyConfig.minClusterPixels}'),
                            Slider(
                              min: 1,
                              max: 20,
                              divisions: 19,
                              value: tempTinyConfig.minClusterPixels.toDouble(),
                              label: tempTinyConfig.minClusterPixels.toString(),
                              onChanged: (v) {
                                setStateDialog(() {
                                  tempTinyConfig.minClusterPixels = v.round();
                                });
                              },
                            ),
                            Row(
                              children: [
                                const Text('Color Filter Enabled'),
                                Switch(
                                  value: tempTinyConfig.colorFilterEnabled,
                                  onChanged: (v) {
                                    setStateDialog(() {
                                      tempTinyConfig.colorFilterEnabled = v;
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (tempTinyConfig.colorFilterEnabled) ...[
                              Text('HSV hMin: ${tempTinyConfig.hMin}'),
                              Slider(
                                min: 0,
                                max: 255,
                                divisions: 255,
                                value: tempTinyConfig.hMin.toDouble(),
                                label: tempTinyConfig.hMin.toString(),
                                onChanged: (v) {
                                  setStateDialog(() {
                                    tempTinyConfig.hMin = v.round();
                                  });
                                },
                              ),
                              Text('HSV hMax: ${tempTinyConfig.hMax}'),
                              Slider(
                                min: 0,
                                max: 255,
                                divisions: 255,
                                value: tempTinyConfig.hMax.toDouble(),
                                label: tempTinyConfig.hMax.toString(),
                                onChanged: (v) {
                                  setStateDialog(() {
                                    tempTinyConfig.hMax = v.round();
                                  });
                                },
                              ),
                              Text('HSV sMin: ${tempTinyConfig.sMin}'),
                              Slider(
                                min: 0,
                                max: 255,
                                divisions: 255,
                                value: tempTinyConfig.sMin.toDouble(),
                                label: tempTinyConfig.sMin.toString(),
                                onChanged: (v) {
                                  setStateDialog(() {
                                    tempTinyConfig.sMin = v.round();
                                  });
                                },
                              ),
                              Text('HSV sMax: ${tempTinyConfig.sMax}'),
                              Slider(
                                min: 0,
                                max: 255,
                                divisions: 255,
                                value: tempTinyConfig.sMax.toDouble(),
                                label: tempTinyConfig.sMax.toString(),
                                onChanged: (v) {
                                  setStateDialog(() {
                                    tempTinyConfig.sMax = v.round();
                                  });
                                },
                              ),
                              Text('HSV vMin: ${tempTinyConfig.vMin}'),
                              Slider(
                                min: 0,
                                max: 255,
                                divisions: 255,
                                value: tempTinyConfig.vMin.toDouble(),
                                label: tempTinyConfig.vMin.toString(),
                                onChanged: (v) {
                                  setStateDialog(() {
                                    tempTinyConfig.vMin = v.round();
                                  });
                                },
                              ),
                              Text('HSV vMax: ${tempTinyConfig.vMax}'),
                              Slider(
                                min: 0,
                                max: 255,
                                divisions: 255,
                                value: tempTinyConfig.vMax.toDouble(),
                                label: tempTinyConfig.vMax.toString(),
                                onChanged: (v) {
                                  setStateDialog(() {
                                    tempTinyConfig.vMax = v.round();
                                  });
                                },
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  child: const Text('Select'),
                  onPressed: () {
                    setState(() {
                      _selectedColor = tempColor;
                      if (_detectionMode == DetectionMode.blob) {
                        _pixelStep = tempPixelStep;
                        _minBlobSize = tempMinBlobSize;
                      } else {
                        _tinyPointDetector.config = tempTinyConfig;
                      }
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _laserDetector = LaserDetector(_logNotifier);
    _tinyPointDetector = TinyPointDetector(_logNotifier, TinyPointDetectorConfig());
    _detectionManager = DetectionManager(
      blobDetector: _laserDetector,
      tinyPointDetector: _tinyPointDetector,
      mode: _detectionMode,
    );
    if (cameras.isNotEmpty) {
      _restartCamera(_selectedPreset);
    } else {
      // No camera available
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Camera Error'),
            content: const Text('No camera found on this device.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    }
  }

  // Throttle frame processing to every 5th frame to prevent freezing at high resolutions
  void _processCameraImage(CameraImage image) {
    if (_isProcessingFrame) return;
    _isProcessingFrame = true;
    _frameCount++;
    const int throttle = 5; // Process every 5th frame
    if (_frameCount % throttle != 0) {
      _isProcessingFrame = false;
      return;
    }
    _detectionManager.mode = _detectionMode;
    Offset? detected = _detectionManager.detect(
      image,
      _frameCount,
      _selectedColor,
      pixelStep: _pixelStep,
      minBlobSize: _minBlobSize,
    );
    setState(() {
      _laserPositions = detected != null ? [detected] : [];
      _isBlocked = false;
    });
    if (_laserPositions.isNotEmpty) {
      _gameLogic.updateLaser(_laserPositions.first, _isBlocked);
    }
    _isProcessingFrame = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(
        body: Center(child: Text('Initializing camera...')),
      );
    }
    if (!_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text('Resolution: ', style: TextStyle(fontSize: 16)),
                DropdownButton<ResolutionPreset>(
                  value: _selectedPreset,
                  items: _presetMap.entries
                      .map((entry) => DropdownMenuItem<ResolutionPreset>(
                            value: entry.value,
                            child: Text(entry.key),
                          ))
                      .toList(),
                  onChanged: (preset) {
                    if (preset != null) {
                      setState(() {
                        _selectedPreset = preset;
                      });
                      _restartCamera(preset);
                    }
                  },
                ),
                const SizedBox(width: 24),
                const Text('Detection Mode: ', style: TextStyle(fontSize: 16)),
                DropdownButton<DetectionMode>(
                  value: _detectionMode,
                  items: [
                    DropdownMenuItem(
                      value: DetectionMode.blob,
                      child: const Text('Blob'),
                    ),
                    DropdownMenuItem(
                      value: DetectionMode.tinyPoint,
                      child: const Text('Tiny Point'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) {
                      // Only update state, do not trigger detection or heavy work here
                      setState(() {
                        _detectionMode = mode;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            flex: 8,
            child: LayoutBuilder(
              builder: (context, constraints) {
                List<Offset> mappedLasers = _laserPositions
                    .map((pos) => Offset(
                        pos.dx * constraints.maxWidth / _controller!.value.previewSize!.width,
                        pos.dy * constraints.maxHeight / _controller!.value.previewSize!.height))
                    .toList();
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_controller!),
                    CustomPaint(
                      painter: OverlayPainter(
                        laserPositions: mappedLasers,
                        isBlocked: _isBlocked,
                        color: _selectedColor,
                      ),
                      child: Container(),
                    ),
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Card(
                        color: Colors.white70,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text('Hits: ${_gameLogic.hitCount}', style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 20,
                      child: ElevatedButton(
                        onPressed: _showColorPicker,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: _selectedColor,
                            ),
                            const SizedBox(width: 8),
                            const Text('Pick Color'),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black,
              child: ValueListenableBuilder<List<String>>(
                valueListenable: _logNotifier,
                builder: (context, logs, _) {
                  return ListView(
                    reverse: true,
                    children: logs.reversed
                        .map((line) => Text(
                              line,
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'monospace',
                                fontSize: 10,
                              ),
                            ))
                        .toList(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
