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
  double _shakeThreshold = 15;
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

  void _changeResolution(ResolutionPreset newPreset) {
    if (_isCountingDown || _currentResolution == newPreset) return;
      _initCamera(_selectedCameraIndex, resolution: newPreset);
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

  void _incrementTimer() {
    if (_isCountingDown || _selectedCountdownSeconds >= 10) return;
    setState(() {
      _selectedCountdownSeconds++;
    });
  }

  void _decrementTimer() {
    if (_isCountingDown || _selectedCountdownSeconds <= 3) return;
    setState(() {
      _selectedCountdownSeconds--;
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
                child: Column(
                  children: [
                    Container(
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

                    SizedBox(height: 10,),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [

                          // ปุ่มลด
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.remove,
                              color: (_isCountingDown || _selectedCountdownSeconds <= 3)
                                  ? Colors.white30
                                  : Colors.white,
                            ),
                            onPressed: (_isCountingDown || _selectedCountdownSeconds <= 3)? null : _decrementTimer,
                          ),

                          const Icon(
                            Icons.timer_outlined,
                            color: Colors.white,
                            size: 16.0,
                          ),

                          Text(
                            '${_selectedCountdownSeconds}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            )
                          ),

                          // ปุ่มเพิ่ม
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.add,
                              color: (_isCountingDown || _selectedCountdownSeconds >= 10)
                                  ? Colors.white30
                                  : Colors.white,
                            ),
                            onPressed: (_isCountingDown || _selectedCountdownSeconds >= 10)? null : _incrementTimer,
                          ),
                        ],
                      ),
                    ),
                  ]
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
                    'ความแรงในการเขย่า: ${_shakeThreshold.toInt()}',
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
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [

                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: PopupMenuButton<ResolutionPreset>(
                          icon: const Icon(Icons.aspect_ratio, color: Colors.white, size: 26),
                          tooltip: 'เลือกความละเอียด',
                          onSelected: _changeResolution,
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: ResolutionPreset.low,
                              child: Text('Low'),
                            ),
                            const PopupMenuItem(
                              value: ResolutionPreset.medium,
                              child: Text('Medium'),
                            ),
                            const PopupMenuItem(
                              value: ResolutionPreset.high,
                              child: Text('High'),
                            ),
                          ],
                        ),
                      ),
                      
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