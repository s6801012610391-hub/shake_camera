import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'camera_settings_screen.dart';
import 'soundcheck.dart';

List<CameraDescription> _cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ShakeCameraScreen(),
    );
  }
}

class ShakeCameraScreen extends StatefulWidget {
  const ShakeCameraScreen({super.key});

  @override
  State<ShakeCameraScreen> createState() => _ShakeCameraScreenState();
}

class _ShakeCameraScreenState extends State<ShakeCameraScreen> {
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  int _countdown = 0;
  bool _isCountingDown = false;
  Timer? _timer;

  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  final double _maxShakeThreshold = 30;
  double _shakeThresholdPercentage = 50;
  double get _shakeThreshold => _maxShakeThreshold * _shakeThresholdPercentage / 100;
  DateTime _lastShakeTime = DateTime.now();
  ResolutionPreset _currentResolution = ResolutionPreset.high;
  int _selectedCountdownSeconds = 3;

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
    _startListeningShake();
  }

  void _startListeningShake() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      double acceleration = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      DateTime now = DateTime.now();
      if (acceleration > _shakeThreshold && now.difference(_lastShakeTime).inMilliseconds > 2000) {
        _lastShakeTime = now;
        if (!_isCountingDown && _controller != null && _controller!.value.isInitialized) {
          _startCountdown(_selectedCountdownSeconds);
        }
      }
    });
  }

  Future<void> _initCamera(int cameraIndex, {ResolutionPreset? resolution}) async {
    if (_cameras.isEmpty) return;

    if (resolution != null) {
      _currentResolution = resolution;
    }

    await _controller?.dispose();

    _controller = CameraController(
      _cameras[cameraIndex],
      _currentResolution,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _switchCamera() {
    if (_cameras.length < 2 || _isCountingDown) return;
    setState(() {
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });
    _initCamera(_selectedCameraIndex);
  }

  void _startCountdown(int currentTimerSeconds) {
    setState(() {
      _isCountingDown = true;
      _countdown = currentTimerSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 1) {
          _countdown--;
        } else {
          _timer?.cancel();
          _isCountingDown = false;
          _takePicture();
        }
      });
    });
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile image = await _controller!.takePicture();
      await Gal.putImage(image.path);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกรูปภาพลงเครื่องเรียบร้อยแล้ว!'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // แสดงกล้อง
            Center(child: CameraPreview(_controller!)),

            // ป้ายข้อความด้านบน
            Positioned(
              top: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'เขย่ามือถือเพื่อถ่ายรูป',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ตัวเลขนับถอยหลัง
            if (_isCountingDown)
              Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 100,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(2.0, 2.0),
                      ),
                    ],
                  ),
                ),
              ),

            // แถบปุ่มควบคุมด้านล่าง (ปุ่มตั้งค่า + ปุ่มสลับกล้อง + ปุ่ม Sound Check)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ปุ่มตั้งค่า (เปิดหน้า SettingsScreen)
                  FloatingActionButton(
                    heroTag: 'settings_btn',
                    onPressed: _isCountingDown
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsScreen(
                                  shakeThresholdPercentage: _shakeThresholdPercentage,
                                  countdownSeconds: _selectedCountdownSeconds,
                                  resolution: _currentResolution,
                                  onShakeThresholdChanged: (val) {
                                    setState(() {
                                      _shakeThresholdPercentage = val;
                                    });
                                  },
                                  onCountdownChanged: (val) {
                                    setState(() {
                                      _selectedCountdownSeconds = val;
                                    });
                                  },
                                  onResolutionChanged: (preset) {
                                    if (_currentResolution != preset) {
                                      _initCamera(_selectedCameraIndex, resolution: preset);
                                    }
                                  },
                                ),
                              ),
                            );
                          },
                    backgroundColor: Colors.blue,
                    child: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  // ปุ่มสลับกล้อง
                  FloatingActionButton(
                    heroTag: 'switch_camera_btn',
                    onPressed: _isCountingDown ? null : _switchCamera,
                    backgroundColor: Colors.blue,
                    child: const Icon(
                      Icons.flip_camera_android,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  // ปุ่ม Sound Check
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(58, 81, 3, 170),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const sound_record(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.mic, size: 18),
                    label: const Text('Sound Check'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}