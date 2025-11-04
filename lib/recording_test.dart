import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const RecordingTestApp());
}

class RecordingTestApp extends StatelessWidget {
  const RecordingTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: RecordingTestPage(),
    );
  }
}

class RecordingTestPage extends StatefulWidget {
  const RecordingTestPage({super.key});

  @override
  _RecordingTestPageState createState() => _RecordingTestPageState();
}

class _RecordingTestPageState extends State<RecordingTestPage> {
  FlutterSoundRecorder? _recorder;
  String? _recordingPath;
  bool _isRecording = false;
  String _status = 'Ready to test recording';

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    setState(() {
      _status = 'Recorder initialized';
    });
  }

  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _status = 'Microphone permission: ${status.isGranted ? 'granted' : 'denied'}';
    });
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    final hasPermission = await _requestPermission();
    if (!hasPermission) return;

    final directory = await getApplicationDocumentsDirectory();
    final fileName = 'test_recording_${DateTime.now().millisecondsSinceEpoch}.wav';
    _recordingPath = '${directory.path}/$fileName';

    setState(() {
      _status = 'Starting recording...';
      _isRecording = true;
    });

    try {
      await _recorder!.startRecorder(
        toFile: _recordingPath,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );

      setState(() {
        _status = 'Recording...';
      });
    } catch (e) {
      setState(() {
        _status = 'Recording failed: $e';
        _isRecording = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _status = 'Stopping recording...';
    });

    try {
      await Future.delayed(const Duration(milliseconds: 500)); // Ensure some audio is captured
      await _recorder!.stopRecorder();

      if (_recordingPath != null) {
        final file = File(_recordingPath!);
        final size = await file.length();
        setState(() {
          _status = 'Recording stopped. File size: $size bytes';
          _isRecording = false;
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Stop recording failed: $e';
        _isRecording = false;
      });
    }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recording Test')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isRecording ? null : _startRecording,
              child: const Text('Start Recording'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : null,
              child: const Text('Stop Recording'),
            ),
            const SizedBox(height: 20),
            if (_recordingPath != null)
              Text('Recording path: ${_recordingPath!.split('/').last}'),
          ],
        ),
      ),
    );
  }
}