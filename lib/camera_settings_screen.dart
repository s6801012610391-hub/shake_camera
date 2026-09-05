import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final double shakeThresholdPercentage;
  final int countdownSeconds;
  final ResolutionPreset resolution;
  final ValueChanged<double> onShakeThresholdChanged;
  final ValueChanged<int> onCountdownChanged;
  final ValueChanged<ResolutionPreset> onResolutionChanged;

  const SettingsScreen({
    super.key,
    required this.shakeThresholdPercentage,
    required this.countdownSeconds,
    required this.resolution,
    required this.onShakeThresholdChanged,
    required this.onCountdownChanged,
    required this.onResolutionChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _shakePercentage;
  late double _countdown;
  late ResolutionPreset _selectedResolution;

  @override
  void initState() {
    super.initState();
    _shakePercentage = widget.shakeThresholdPercentage;
    _countdown = widget.countdownSeconds.toDouble();
    _selectedResolution = widget.resolution;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [

              //Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 36, color: Colors.blue),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              //Camera Settings Text
              const Text(
                'Camera Settings',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              //Shaking Intensity
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Shaking Intensity',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 16),

                    Text('${_shakePercentage.toInt()}%'),

                    Slider(
                      value: _shakePercentage,
                      min: 10.0,
                      max: 100.0,
                      divisions: 18,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey,
                      onChanged: (val) {
                        setState(() => _shakePercentage = val);
                        widget.onShakeThresholdChanged(val);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              //Countdown Timer
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Countdown Timer',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 16),

                    Text('${_countdown.toInt()}s'),

                    Slider(
                      value: _countdown,
                      min: 3.0,
                      max: 10.0,
                      divisions: 7,
                      activeColor: Colors.blue,
                      inactiveColor: Colors.grey,
                      onChanged: (val) {
                        setState(() => _countdown = val);
                        widget.onCountdownChanged(val.toInt());
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              //Photo Quality
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Photo Quality',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),

                    const SizedBox(height: 16),

                    DropdownButton<ResolutionPreset>(
                      value: _selectedResolution,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      items: const [
                        DropdownMenuItem(
                          value: ResolutionPreset.low,
                          child: Text('Low'),
                        ),
                        DropdownMenuItem(
                          value: ResolutionPreset.medium,
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(
                          value: ResolutionPreset.high,
                          child: Text('High'),
                        ),
                      ],
                      onChanged: (newValue) {
                        if (newValue != null) {
                          setState(() => _selectedResolution = newValue);
                          widget.onResolutionChanged(newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}