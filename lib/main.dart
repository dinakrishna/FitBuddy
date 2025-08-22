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
  LaserDetector _laserDetector = LaserDetector();
  GameLogic _gameLogic = GameLogic();
  Offset? _laserPosition;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
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
    final result = _laserDetector.detectLaser(image);
    setState(() {
      _laserPosition = result.laserPosition;
      _isBlocked = result.isBlocked;
    });
    _gameLogic.updateLaser(_laserPosition, _isBlocked);
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
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                CustomPaint(
                  painter: OverlayPainter(
                    laserPosition: _laserPosition,
                    isBlocked: _isBlocked,
                  ),
                  child: Container(),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Card(
                    color: Colors.white70,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text('Hits: {_gameLogic.hitCount}', style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
