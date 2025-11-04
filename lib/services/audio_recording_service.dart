import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app_logger.dart';

class AudioRecordingService {
  FlutterSoundRecorder? _recorder;
  FlutterSoundPlayer? _player;
  bool _isInitialized = false;
  String? _currentRecordingPath;

  // Alternative recorder using the record package
  final AudioRecorder _audioRecorder = AudioRecorder();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _recorder = FlutterSoundRecorder();
      _player = FlutterSoundPlayer();

      await AppLogger.logReadingAloudEvent('Initializing audio recorder');
      await _recorder!.openRecorder();
      await AppLogger.logReadingAloudEvent('Initializing audio player');
      await _player!.openPlayer();

      _isInitialized = true;
      await AppLogger.logReadingAloudEvent('Audio services initialized successfully');
    } catch (e) {
      await AppLogger.logReadingAloudError('Failed to initialize audio services: $e');
      rethrow;
    }
  }

  Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      await AppLogger.logReadingAloudEvent('Microphone permission status', details: '${status.isGranted}');
      return status.isGranted;
    } catch (e) {
      await AppLogger.logReadingAloudError('Failed to request microphone permission: $e');
      return false;
    }
  }

  Future<String> startRecording() async {
    // Use the record package instead of flutter_sound
    return await startRecordingWithRecord();
  }

  Future<String?> stopRecording() async {
    // Use the record package instead of flutter_sound
    return await stopRecordingWithRecord();
  }

  Future<void> playRecording(String filePath) async {
    if (!_isInitialized) await initialize();

    try {
      await AppLogger.logReadingAloudEvent('Playing recording', details: 'Path: ${filePath.split('/').last}');

      // Check if file exists and get its size
      final file = File(filePath);
      if (!await file.exists()) {
        await AppLogger.logReadingAloudError('Recording file not found', context: filePath);
        throw Exception('Recording file not found: $filePath');
      }

      final size = await file.length();
      await AppLogger.logReadingAloudEvent('Recording file size for playback', details: '$size bytes');

      if (size <= 100) {
        await AppLogger.logReadingAloudError('Recording file is too small (only header)', context: '$size bytes');
        throw Exception('Recording file is too small to play (only header)');
      }

      // Use aacADTS codec for record package output
      await _player!.startPlayer(
        fromURI: filePath,
        codec: Codec.aacADTS, // Record package produces AAC files
        sampleRate: 16000,
        numChannels: 1,
      );

      await AppLogger.logReadingAloudEvent('Recording playback started');
    } catch (e) {
      await AppLogger.logReadingAloudError('Failed to play recording: $e');
      rethrow;
    }
  }

  Future<void> stopPlayback() async {
    if (!_isInitialized || _player!.isStopped) return;

    await _player!.stopPlayer();
  }

  Future<void> dispose() async {
    try {
      await AppLogger.logReadingAloudEvent('Disposing audio services');
      if (_recorder != null) {
        if (_recorder!.isRecording) {
          await _recorder!.stopRecorder();
        }
        await _recorder!.closeRecorder();
        _recorder = null;
      }
      if (_player != null) {
        if (_player!.isPlaying) {
          await _player!.stopPlayer();
        }
        await _player!.closePlayer();
        _player = null;
      }
      // Dispose record package recorder
      if (await _audioRecorder.isRecording()) {
        await _audioRecorder.stop();
      }
      await _audioRecorder.dispose();

      _isInitialized = false;
      await AppLogger.logReadingAloudEvent('Audio services disposed successfully');
    } catch (e) {
      await AppLogger.logReadingAloudError('Error disposing audio services: $e');
    }
  }

  // Alternative implementation using the record package
  Future<String> startRecordingWithRecord() async {
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
      await AppLogger.logReadingAloudError('Microphone permission denied');
      throw Exception('Microphone permission denied');
    }

    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = '${directory.path}/$fileName';

      await AppLogger.logReadingAloudEvent('Starting recording with record package', details: 'Path: $_currentRecordingPath');

      // Check if already recording
      if (await _audioRecorder.isRecording()) {
        await AppLogger.logReadingAloudEvent('Record package already recording, stopping first');
        await _audioRecorder.stop();
      }

      // Start recording with record package
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      await AppLogger.logReadingAloudEvent('Recording started with record package successfully');
      return _currentRecordingPath!;
    } catch (e) {
      await AppLogger.logReadingAloudError('Failed to start recording with record package: $e');
      rethrow;
    }
  }

  Future<String?> stopRecordingWithRecord() async {
    try {
      await AppLogger.logReadingAloudEvent('Stopping recording with record package');

      final path = await _audioRecorder.stop();
      await AppLogger.logReadingAloudEvent('Recording stopped with record package', details: 'Path: $path');

      if (path != null) {
        final file = File(path);
        final size = await file.length();
        await AppLogger.logReadingAloudEvent('Recorded file size (record package)', details: '$size bytes');

        if (size <= 100) {
          await AppLogger.logReadingAloudError('Recording file contains only header (record package)', context: '$size bytes');
        }
      }

      return path;
    } catch (e) {
      await AppLogger.logReadingAloudError('Failed to stop recording with record package: $e');
      return null;
    }
  }
}