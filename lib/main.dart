

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'laser_detector.dart';
import 'overlay_painter.dart';
import 'game_logic.dart';
import 'package:flutter/services.dart';

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
  Color _selectedColor = Colors.red;
  CameraController? _controller;
  late LaserDetector _laserDetector;
  GameLogic _gameLogic = GameLogic();
  List<Offset> _laserPositions = [];
  bool _isBlocked = false;
  int _frameCount = 0;
  final ValueNotifier<List<String>> _logNotifier = ValueNotifier([]);

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = _selectedColor;
        final media = MediaQuery.of(context);
        final double dialogWidth = media.size.width * 0.9;
        final double dialogHeight = media.size.height * 0.9;
        return Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: dialogHeight,
            ),
            child: AlertDialog(
              title: const Text('Pick Laser Color'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              content: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 800,
                      minWidth: 400,
                    ),
                    child: ColorPicker(
                      pickerColor: tempColor,
                      onColorChanged: (color) {
                        tempColor = color;
                      },
                      showLabel: true,
                      pickerAreaHeightPercent: 0.8,
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Select'),
                  onPressed: () {
                    setState(() {
                      _selectedColor = tempColor;
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
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _controller!.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller!.startImageStream(_processCameraImage);
      });
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

  void _processCameraImage(CameraImage image) {
    _frameCount++;
    final blobCenters = _laserDetector.detectBlobsByColor(image, _frameCount, _selectedColor);
    setState(() {
      _laserPositions = blobCenters;
      _isBlocked = false;
    });
    if (_laserPositions.isNotEmpty) {
      _gameLogic.updateLaser(_laserPositions.first, _isBlocked);
    }
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
