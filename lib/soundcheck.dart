import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart'; 
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'main.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // ปิดแถบ Debug มุมขวาบน (optional)
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const sound_record(), 
    );
  }
}

class sound_record extends StatefulWidget {
  const sound_record({super.key});

  @override
  State<sound_record> createState() => _sound_recordState();
}

enum AudioQuality { low, medium, high }
class _sound_recordState extends State<sound_record> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;

  final _audioplayer = AudioPlayer();
  bool isPlaying = false;

  Duration _duration = Duration.zero; // ความยาวไฟล์เสียง
  Duration _position = Duration.zero; // ตำแหน่งเวลา

  Timer? _recordTimer;
  int _recordDuration = 0;

  AudioQuality _selectedQuality = AudioQuality.high;

  Future<void> startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      int bitRate;
      int sampleRate;

      switch (_selectedQuality) {
        case AudioQuality.low:
          bitRate = 24000;
          sampleRate = 8000;
          break;
        case AudioQuality.medium:
          bitRate = 68000;
          sampleRate = 24000;
          break;
        case AudioQuality.high:
          bitRate = 192000;
          sampleRate = 48000;
          break;
      }

      if (kIsWeb) {
        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.opus,
            bitRate: bitRate,
            sampleRate: sampleRate,
          ), 
          path: '',
        );
      } else {
      String path = '';

      if (Platform.isAndroid) {
        // ชี้ไปที่โฟลเดอร์ Download หลักของเครื่อง Android
        final Directory downloadDir = Directory('/storage/emulated/0/Download');
        
        // ตรวจสอบว่าโฟลเดอร์มีจริงไหม ถ้าไม่มีให้สร้าง
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        
        path = '${downloadDir.path}/my_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        // สำหรับระบบอื่นๆ (เช่น Windows / macOS / Linux) ใช้ Documents เหมือนเดิม
        final dir = await getApplicationDocumentsDirectory();
        path = '${dir.path}/my_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await _audioRecorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: bitRate,
          sampleRate: sampleRate,
        ), 
        path: path,
      );
    }
      setState(() {
        _isRecording = true;
        _recordDuration = 0;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordDuration++;
        });
      });
      
    }
  }

Future<void> stopRecording() async {
  // หยุดบันทึกและรับ Path/URL ของไฟล์
  final path = await _audioRecorder.stop();

  _recordTimer?.cancel();

  setState(() {
    _audioPath = path; 
    _isRecording = false;
  });
}

  @override
  void initState() {
    super.initState();

    // 1. ดักฟังสถานะ Play / Pause
    _audioplayer.onPlayerStateChanged.listen((state) {
      setState(() {
        isPlaying = (state == PlayerState.playing);
      });
    });

    // 2. ดักฟังความยาวรวม (แยกออกมาอยู่นอกสุด)
    _audioplayer.onDurationChanged.listen((newDuration) {
      setState(() {
        _duration = newDuration;
      });
    });

    // 3. ดักฟังเวลาที่เล่นอยู่ realtime (แยกออกมาอยู่นอกสุด)
    _audioplayer.onPositionChanged.listen((newPosition) {
      setState(() {
        _position = newPosition;
      });
    });

    // 4. ดักฟังเมื่อเล่นจบ (แยกออกมาอยู่นอกสุด)
    _audioplayer.onPlayerComplete.listen((_) {
      setState(() {
        _position = Duration.zero;
      });
    });
  }

  Future<void> playAudio() async {
    if (_audioPath == null) return; // ถ้ายังไม่มีไฟล์ ให้ข้ามไป

    if (isPlaying) {
      await _audioplayer.pause();
    } else {
      // ถ้าหยุดอยู่ ให้เลือกวิธีเปิดฟังตามระบบปฏิบัติการ
      if (kIsWeb) {
        await _audioplayer.play(UrlSource(_audioPath!));
      } else {
        await _audioplayer.play(DeviceFileSource(_audioPath!));
      }
    }
  }

  String formatDuration(Duration duration) {
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final minutes = twoDigits(duration.inMinutes.remainder(60));
      final seconds = twoDigits(duration.inSeconds.remainder(60));
      return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final double maxSeconds = _duration.inSeconds.toDouble();
    final double currentSeconds = _position.inSeconds.toDouble();
       

    return Scaffold(
      body:Center(
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                iconSize: 40,
                icon: const Icon(Icons.arrow_back),
                onPressed:(){
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ShakeCameraScreen(),
                    ),
                  );
                 }),
            ]
          ),

          DropdownButton<AudioQuality>(
            value: _selectedQuality,
            items: const [
                        DropdownMenuItem(
                          value: AudioQuality.low,
                          child: Text('Low Quality (32 kbps)'),
                        ),
                        DropdownMenuItem(
                          value: AudioQuality.medium,
                          child: Text('Medium Quality (96 kbps)'),
                        ),
                        DropdownMenuItem(
                          value: AudioQuality.high,
                          child: Text('High Quality (192 kbps)'),
                        ),
                    ],
            onChanged: _isRecording ? null:(AudioQuality? newValue){
              if(newValue != null){
                setState(() {
                  _selectedQuality = newValue;
                });
              }
            }
          ),

          if (_isRecording) ...[
              const SizedBox(height: 10),
              Text(
                formatDuration(Duration(seconds: _recordDuration)),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          
          IconButton(
            icon: Icon(Icons.mic),
            iconSize: 42.0, // Adjust size
            color: _isRecording ? Colors.red : const Color.fromARGB(255, 121, 2, 145), // Adjust color
            onPressed: () {
              if(_isRecording == false){
                startRecording();
              }
              else{
                stopRecording();
              }
            },
          ),
          SizedBox(height: 50),

          if(_audioPath != null)
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 36.0,
              color: const Color.fromARGB(255, 35, 88, 235),
              onPressed: (){
                playAudio();
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Slider(
                      // ป้องกันค่า value เกิน max
                      value: currentSeconds.clamp(0.0, maxSeconds > 0 ? maxSeconds : 1.0),
                      min: 0.0,
                      max: maxSeconds > 0 ? maxSeconds : 1.0,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey[300],
                      onChanged: (double value) async {
                        final newPosition = Duration(seconds: value.toInt());
                        // สั่งให้เครื่องเล่นข้ามไปยังตำแหน่งที่ลาก
                        await _audioplayer.seek(newPosition);
                      },
                    ),
                    // แสดงตัวเลขเวลา (เวลาปัจจุบัน / ความยาวทั้งหมด)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(formatDuration(_position)),
                        Text(formatDuration(_duration)),
                      ],
                    ),
                  ],
                ),
              ),
            ]
        ),
      ),
    );
  }
}
