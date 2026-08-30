import 'dart:async';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
  double _shakeThreshold = 15.0;
  DateTime _lastShakeTime = DateTime.now();

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
          _startCountdown();
        }
      }
    });
  }

  Future<void> _initCamera(int cameraIndex) async {
    if (_cameras.isEmpty) return;
    await _controller?.dispose();

    _controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high,
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

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
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

            // แถบปุ่มควบคุมด้านล่าง (ปุ่มสลับกล้อง + ปุ่ม Sound Check + Slider)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ความแรงในการเขย่า: ${_shakeThreshold.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                    ),
                  ),
                  
                  Slider(
                    value: _shakeThreshold,
                    min: 5.0,
                    max: 30.0,
                    divisions: 25,
                    activeColor: Colors.blue,
                    inactiveColor: Colors.white60,
                    onChanged: (double value) {
                      setState(() {
                        _shakeThreshold = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [

                      const SizedBox(width: 100),
                      
                      FloatingActionButton(
                        onPressed: _isCountingDown ? null : _switchCamera,
                        backgroundColor: Colors.blue,
                        child: const Icon(
                          Icons.flip_camera_android,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),

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
                          Navigator.push(
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
                ],
              )
            ),
          ],
        ),
      ),
    );
  }
}