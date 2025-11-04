import 'package:flutter/material.dart';
import 'dart:io';
import '../database_helper.dart';
import '../services/text_to_speech_service.dart';
import '../services/audio_recording_service.dart';
import '../services/ai_assessment_service.dart';
import '../services/app_logger.dart';

class ReadingAloudPage extends StatefulWidget {
  final TextStory? selectedStory;

  const ReadingAloudPage({super.key, this.selectedStory});

  @override
  _ReadingAloudPageState createState() => _ReadingAloudPageState();
}

class _ReadingAloudPageState extends State<ReadingAloudPage> {
  final TextEditingController _textController = TextEditingController();
  String _text = '';
  final TextToSpeechService _ttsService = TextToSpeechService();
  final AudioRecordingService _recordingService = AudioRecordingService();
  final AIAssessmentService _assessmentService = AIAssessmentService();

  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isRecording = false;
  bool _isAssessing = false;
  String? _currentRecordingPath;
  String? _compressedRecordingPath;
  Map<String, dynamic>? _assessmentResult;

  @override
  void initState() {
    super.initState();
    if (widget.selectedStory != null) {
      _textController.text = widget.selectedStory!.text;
      _text = widget.selectedStory!.text;
    }
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _ttsService.initialize();
    await _recordingService.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking) {
      await _ttsService.stop();
      await AppLogger.logReadingAloudEvent('TTS stopped');
      setState(() {
        _isSpeaking = false;
      });
    } else {
      await AppLogger.logReadingAloudEvent('Starting TTS', details: 'Text length: ${_text.length}');
      await _ttsService.speak(_text);
      setState(() {
        _isSpeaking = true;
      });
      // Reset speaking state after speech completes
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final recordingPath = await _recordingService.stopRecording();
      await AppLogger.logReadingAloudEvent('Recording stopped', details: 'Path: ${recordingPath?.split('/').last}');
      setState(() {
        _isRecording = false;
        _currentRecordingPath = recordingPath;
      });

      if (recordingPath != null) {
        // Note: Compression temporarily disabled due to library issues
        // TODO: Re-enable compression when a stable library is available
        setState(() {
          _compressedRecordingPath = recordingPath; // Use original file for now
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recording saved successfully')),
        );
      }
    } else {
      await AppLogger.logReadingAloudEvent('Starting audio recording');
      final recordingPath = await _recordingService.startRecording();
      setState(() {
        _isRecording = true;
        _currentRecordingPath = recordingPath;
      });
    }
  }

  Future<void> _playRecording(String filePath) async {
    try {
      await _recordingService.playRecording(filePath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play recording: $e')),
      );
    }
  }

  Future<void> _testRecording() async {
    try {
      await AppLogger.logReadingAloudEvent('Testing recording functionality');
      
      // Start recording
      final path = await _recordingService.startRecording();
      await AppLogger.logReadingAloudEvent('Test recording started', details: 'Path: $path');
      
      // Wait 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      
      // Stop recording
      final stoppedPath = await _recordingService.stopRecording();
      await AppLogger.logReadingAloudEvent('Test recording stopped', details: 'Path: $stoppedPath');
      
      if (stoppedPath != null) {
        final file = File(stoppedPath);
        final size = await file.length();
        await AppLogger.logReadingAloudEvent('Test recording file size', details: '$size bytes');
        
        if (size > 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test recording successful: $size bytes')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test recording failed: only $size bytes')),
          );
        }
      }
    } catch (e) {
      await AppLogger.logReadingAloudError('Test recording failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Test recording error: $e')),
      );
    }
  }

  Future<void> _assessPronunciation() async {
    if (_compressedRecordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record your voice first')),
      );
      return;
    }

    await AppLogger.logReadingAloudEvent('Starting pronunciation assessment', details: 'Expected text: "${_text.substring(0, 50)}${_text.length > 50 ? '...' : ''}"');

    setState(() {
      _isAssessing = true;
    });

    try {
      final result = await _assessmentService.assessPronunciation(_compressedRecordingPath!, _text);
      setState(() {
        _assessmentResult = result;
      });
      
      await AppLogger.logReadingAloudEvent('Pronunciation assessment completed', details: 'Score: ${result['overall_score']}');
    } catch (e) {
      await AppLogger.logReadingAloudError('Pronunciation assessment failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Assessment failed: $e')),
      );
    } finally {
      setState(() {
        _isAssessing = false;
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _recordingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reading Aloud Practice'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.selectedStory != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedStory!.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Author: ${widget.selectedStory!.author}'),
                      Text('Theme: ${widget.selectedStory!.theme}'),
                      Text('Language: ${widget.selectedStory!.language}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Text to Read Aloud',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Enter text to practice reading aloud...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _text = value;
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_text.length} characters',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                if (_text.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    onPressed: () {
                      setState(() {
                        _textController.clear();
                        _text = '';
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 40),
            const Center(
              child: Text(
                'Reading Aloud Controls',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isInitialized)
              const Center(child: CircularProgressIndicator())
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(_isSpeaking ? Icons.stop : Icons.play_arrow),
                          label: Text(_isSpeaking ? 'Stop' : 'Speak'),
                          onPressed: _text.isEmpty ? null : _toggleSpeech,
                        ),
                        ElevatedButton.icon(
                          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                          label: Text(_isRecording ? 'Stop Recording' : 'Record'),
                          onPressed: _toggleRecording,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.red : null,
                          ),
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.bug_report),
                          label: const Text('Test Record'),
                          onPressed: _testRecording,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_currentRecordingPath != null)
                      Column(
                        children: [
                          const Text('Recording saved:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            _currentRecordingPath!.split('/').last,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Play Recording'),
                                onPressed: () => _playRecording(_currentRecordingPath!),
                              ),
                              ElevatedButton.icon(
                                icon: _isAssessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.assessment),
                                label: Text(_isAssessing ? 'Assessing...' : 'Assess Pronunciation'),
                                onPressed: _isAssessing ? null : _assessPronunciation,
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            if (_assessmentResult != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pronunciation Assessment',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Overall Score: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${_assessmentResult!['overall_score'].toStringAsFixed(1)}/100',
                          style: TextStyle(
                            color: _assessmentResult!['overall_score'] >= 80 ? Colors.green : _assessmentResult!['overall_score'] >= 60 ? Colors.orange : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Fluency Score: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('${_assessmentResult!['fluency_score'].toStringAsFixed(1)}/100'),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Text('Pronunciation Issues:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    ...(_assessmentResult!['pronunciation_issues'] is List ? (_assessmentResult!['pronunciation_issues'] as List<dynamic>).map<String>((issue) => issue.toString()) : <String>[]).map((issue) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.warning, size: 16, color: Colors.orange),
                            const SizedBox(width: 5),
                            Expanded(child: Text('• $issue')),
                          ],
                        ),
                      ),
                    ).toList(),
                    const SizedBox(height: 15),
                    const Text('Suggestions:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    ...(_assessmentResult!['suggestions'] is List ? (_assessmentResult!['suggestions'] as List<dynamic>).map<String>((suggestion) => suggestion.toString()) : <String>[]).map((suggestion) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 10, bottom: 5),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                            const SizedBox(width: 5),
                            Expanded(child: Text('• $suggestion')),
                          ],
                        ),
                      ),
                    ).toList(),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}