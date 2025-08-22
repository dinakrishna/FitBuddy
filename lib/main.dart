import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'laser_detector.dart';
import 'overlay_painter.dart';
import 'game_logic.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  CameraController? _controller;
  late LaserDetector _laserDetector;
  GameLogic _gameLogic = GameLogic();
  List<Offset> _laserPositions = [];
  bool _isBlocked = false;
  int _frameCount = 0;
  final ValueNotifier<List<String>> _logNotifier = ValueNotifier([]);

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
    }
  }

  void _processCameraImage(CameraImage image) {
    _frameCount++;
    final blobCenters = _laserDetector.detectRedBlobs(image, _frameCount);
    setState(() {
      _laserPositions = blobCenters;
      _isBlocked = false; // Placeholder: always false for now
    });
    // Optionally, update game logic with first blob
    if (_laserPositions.isNotEmpty) {
      _gameLogic.updateLaser(_laserPositions.first, _isBlocked);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
