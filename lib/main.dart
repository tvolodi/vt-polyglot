import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:convert';

class TextToSpeechService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
  }

  Future<void> pause() async {
    if (!_isInitialized) return;
    await _flutterTts.pause();
  }

  Future<List<String>> getLanguages() async {
    if (!_isInitialized) await initialize();
    return await _flutterTts.getLanguages;
  }

  Future<List<String>> getVoices() async {
    if (!_isInitialized) await initialize();
    return await _flutterTts.getVoices;
  }

  Future<void> setLanguage(String language) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setLanguage(language);
  }

  Future<void> setSpeechRate(double rate) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setSpeechRate(rate);
  }

  Future<void> setVolume(double volume) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setVolume(volume);
  }

  Future<void> setPitch(double pitch) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setPitch(pitch);
  }

  Future<void> setVoice(String voice) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.setVoice({'name': voice, 'locale': 'en-US'});
  }
}

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

class AudioCompressionService {
  // Note: Audio compression temporarily disabled due to library compatibility issues
  // TODO: Implement compression using a maintained library like ffmpeg_kit or native platform code

  Future<String> compressAudio(String inputPath, String outputPath) async {
    // For now, just return the input path (no compression)
    // This allows the app to work while compression is being resolved
    return inputPath;
  }

  Future<String> compressToOgg(String inputPath, String outputPath) async {
    // For now, just return the input path (no compression)
    return inputPath;
  }

  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    return await file.length();
  }

  Future<double> getCompressionRatio(String originalPath, String compressedPath) async {
    // Since we're not compressing, ratio is 1.0
    return 1.0;
  }
}

class AIAssessmentService {
  // Speech-to-text instance for real-time transcription
  final SpeechToText _speechToText = SpeechToText();
  bool _speechToTextAvailable = false;

  Future<void> initialize() async {
    _speechToTextAvailable = await _speechToText.initialize(
      onStatus: (status) => AppLogger.logReadingAloudEvent('Speech-to-text status', details: status),
      onError: (error) => AppLogger.logReadingAloudError('Speech-to-text error', context: error.errorMsg),
    );
    await AppLogger.logReadingAloudEvent('Speech-to-text initialized', details: 'Available: $_speechToTextAvailable');
  }
  Future<Map<String, dynamic>> assessPronunciation(String audioFilePath, String expectedText) async {
    await AppLogger.logReadingAloudEvent('Starting pronunciation assessment', details: 'Expected text: "${expectedText.substring(0, 50)}${expectedText.length > 50 ? '...' : ''}"');

    try {
      // Initialize speech-to-text if not already done
      if (!_speechToTextAvailable) {
        await initialize();
      }

      if (!_speechToTextAvailable) {
        await AppLogger.logReadingAloudError('Speech-to-text not available on this device');
        throw Exception('Speech-to-text is not available on this device. Please check microphone permissions and device capabilities.');
      }

      // Get AI configuration for assessment (not needed for transcription anymore)
      AIModelConfig? aiConfig = await getAIModelConfigForFunction('default');

      if (aiConfig == null || aiConfig.apiKey.isEmpty) {
        await AppLogger.logReadingAloudError('AI API key not configured for assessment');
        throw Exception('AI API key not configured. Please set up API configuration in Settings.');
      }

      // Use speech-to-text for real-time transcription
      final transcription = await _transcribeWithSpeechToText(expectedText);

      await AppLogger.logReadingAloudEvent('Real-time transcription completed', details: 'Transcription: "$transcription"');

      // Use AI to analyze the transcription against expected text
      final model = GenerativeModel(model: aiConfig.modelCode, apiKey: aiConfig.apiKey);
      
      final prompt = '''
Analyze this pronunciation assessment request:

Expected text: "$expectedText"
Transcribed text: "$transcription"

Please provide a detailed pronunciation assessment including:
1. Overall score (0-100) based on how well the transcription matches the expected text
2. Word-by-word accuracy analysis with specific issues
3. Pronunciation issues identified
4. Fluency score (0-100)
5. Specific suggestions for improvement

Consider factors like:
- Word accuracy (correct vs incorrect words)
- Spelling accuracy in transcription
- Potential pronunciation errors that might cause transcription differences
- Overall clarity and fluency

Return your response as a valid JSON object with exactly these keys:
- overall_score: number
- word_accuracy: array of objects with "word", "accuracy" (0-100), and "issues" array
- pronunciation_issues: array of strings
- fluency_score: number
- suggestions: array of strings

IMPORTANT: Make sure the JSON is valid and properly escaped. Do not include any text before or after the JSON object.
''';

      await AppLogger.logAISentMessage(prompt);

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text;

      if (responseText == null || responseText.trim().isEmpty) {
        await AppLogger.logReadingAloudError('No response from AI API');
        throw Exception('No response from AI API');
      }

      await AppLogger.logAIReceivedResponse(responseText);

      // Clean and parse the JSON response
      String cleanResponse = responseText.trim();
      
      // Remove markdown code blocks if present
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.substring(7);
      }
      if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse.substring(3);
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3);
      }
      
      cleanResponse = cleanResponse.trim();

      // Try to extract JSON from the response if it's embedded in text
      Map<String, dynamic>? assessmentData;
      try {
        assessmentData = jsonDecode(cleanResponse);
      } catch (e) {
        print('Direct JSON parsing failed: $e');
        print('Response text: $cleanResponse');
        
        // If direct parsing fails, try to find JSON object in the response
        final jsonStart = cleanResponse.indexOf('{');
        final jsonEnd = cleanResponse.lastIndexOf('}');
        
        if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
          final jsonString = cleanResponse.substring(jsonStart, jsonEnd + 1);
          try {
            assessmentData = jsonDecode(jsonString);
          } catch (e2) {
            print('Failed to parse extracted JSON: $e2');
            print('Extracted JSON string: $jsonString');
            
            // Try to manually extract key-value pairs from malformed JSON
            try {
              assessmentData = _parseMalformedJson(jsonString);
            } catch (e3) {
              print('Failed to parse malformed JSON: $e3');
              
              // Last resort: create a basic response
              assessmentData = {
                'overall_score': 50,
                'word_accuracy': [],
                'pronunciation_issues': ['Unable to analyze response from AI'],
                'fluency_score': 50,
                'suggestions': ['Please try again or check your API key']
              };
            }
          }
        } else {
          // Create fallback response
          assessmentData = {
            'overall_score': 50,
            'word_accuracy': [],
            'pronunciation_issues': ['Unable to parse AI response'],
            'fluency_score': 50,
            'suggestions': ['Please try again']
          };
        }
      }
      
      // Validate required fields
      if (assessmentData == null ||
          !assessmentData.containsKey('overall_score') || 
          !assessmentData.containsKey('word_accuracy') ||
          !assessmentData.containsKey('pronunciation_issues') ||
          !assessmentData.containsKey('fluency_score') ||
          !assessmentData.containsKey('suggestions')) {
        await AppLogger.logReadingAloudError('Invalid response format from AI API - missing required fields');
        throw Exception('Invalid response format from AI API - missing required fields');
      }

      // Ensure lists are properly typed
      final Map<String, dynamic> processedData = {
        'overall_score': assessmentData['overall_score'],
        'word_accuracy': assessmentData['word_accuracy'],
        'pronunciation_issues': List<String>.from(assessmentData['pronunciation_issues'] ?? []),
        'fluency_score': assessmentData['fluency_score'],
        'suggestions': List<String>.from(assessmentData['suggestions'] ?? []),
      };

      await AppLogger.logReadingAloudEvent('Pronunciation assessment completed successfully', 
        details: 'Score: ${processedData['overall_score']}, Issues: ${processedData['pronunciation_issues'].length}');

      return processedData;

    } catch (e) {
      await AppLogger.logReadingAloudError('AI Assessment failed: $e');
      throw Exception('Failed to assess pronunciation: $e');
    }
  }

  // Real-time speech-to-text transcription using speech_to_text package
  Future<String> _transcribeWithSpeechToText(String expectedText) async {
    await AppLogger.logReadingAloudEvent('Starting real-time speech-to-text transcription');

    final completer = Completer<String>();
    String transcription = '';
    bool hasStarted = false;

    _speechToText.listen(
      onResult: (result) {
        transcription = result.recognizedWords;
        AppLogger.logReadingAloudEvent('Speech recognition result', details: 'Text: "$transcription", Confidence: ${result.confidence}, Final: ${result.finalResult}');

        if (result.finalResult) {
          _speechToText.stop();
          completer.complete(transcription);
        }
      },
      onSoundLevelChange: (level) {
        if (!hasStarted && level > 0) {
          hasStarted = true;
          AppLogger.logReadingAloudEvent('Speech detection started', details: 'Sound level: $level');
        }
      },
      listenFor: const Duration(seconds: 30), // Maximum listening time
      pauseFor: const Duration(seconds: 5), // Stop after 5 seconds of silence
      partialResults: true,
      localeId: 'en-US', // Can be made configurable later
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );

    // Timeout after 35 seconds
    Future.delayed(const Duration(seconds: 35), () {
      if (!completer.isCompleted) {
        _speechToText.stop();
        AppLogger.logReadingAloudEvent('Speech-to-text timeout');
        completer.complete(transcription.isNotEmpty ? transcription : 'No speech detected');
      }
    });

    return completer.future;
  }

  // Parse malformed JSON by extracting key-value pairs manually
  Map<String, dynamic> _parseMalformedJson(String jsonString) {
    final result = <String, dynamic>{
      'overall_score': 50,
      'word_accuracy': [],
      'pronunciation_issues': [],
      'fluency_score': 50,
      'suggestions': [],
    };

    try {
      // Extract overall_score
      final scoreRegex = RegExp(r'"overall_score"\s*:\s*(\d+)');
      final scoreMatch = scoreRegex.firstMatch(jsonString);
      if (scoreMatch != null) {
        result['overall_score'] = int.tryParse(scoreMatch.group(1)!) ?? 50;
      }

      // Extract fluency_score
      final fluencyRegex = RegExp(r'"fluency_score"\s*:\s*(\d+)');
      final fluencyMatch = fluencyRegex.firstMatch(jsonString);
      if (fluencyMatch != null) {
        result['fluency_score'] = int.tryParse(fluencyMatch.group(1)!) ?? 50;
      }

      // Extract pronunciation_issues array
      final issuesRegex = RegExp(r'"pronunciation_issues"\s*:\s*\[([^\]]*)\]');
      final issuesMatch = issuesRegex.firstMatch(jsonString);
      if (issuesMatch != null) {
        final issuesString = issuesMatch.group(1)!;
        // Extract individual strings from the array
        final issueStrings = RegExp(r'"([^"]*)"').allMatches(issuesString)
            .map((match) => match.group(1)!)
            .toList();
        result['pronunciation_issues'] = issueStrings;
      }

      // Extract suggestions array
      final suggestionsRegex = RegExp(r'"suggestions"\s*:\s*\[([^\]]*)\]');
      final suggestionsMatch = suggestionsRegex.firstMatch(jsonString);
      if (suggestionsMatch != null) {
        final suggestionsString = suggestionsMatch.group(1)!;
        // Extract individual strings from the array
        final suggestionStrings = RegExp(r'"([^"]*)"').allMatches(suggestionsString)
            .map((match) => match.group(1)!)
            .toList();
        result['suggestions'] = suggestionStrings;
      }

      // If we couldn't extract any meaningful data, use fallback
      if (result['pronunciation_issues'].isEmpty && result['suggestions'].isEmpty) {
        result['pronunciation_issues'] = ['Unable to analyze response from AI'];
        result['suggestions'] = ['Please try again or check your API key'];
      }

    } catch (e) {
      print('Error in manual JSON parsing: $e');
      // Keep the default fallback values
    }

    return result;
  }
}

class AppLogger {
  static const String _logKey = 'app_logs';
  static const int _maxLogs = 1000; // Keep only the most recent 1000 logs

  static Future<void> log(String message, {String level = 'INFO', String category = 'GENERAL'}) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toIso8601String();
    
    final logEntry = {
      'timestamp': timestamp,
      'level': level,
      'category': category,
      'message': message,
    };

    final logJson = jsonEncode(logEntry);
    final currentLogs = prefs.getStringList(_logKey) ?? [];
    
    currentLogs.add(logJson);
    
    // Keep only the most recent logs
    if (currentLogs.length > _maxLogs) {
      currentLogs.removeRange(0, currentLogs.length - _maxLogs);
    }
    
    await prefs.setStringList(_logKey, currentLogs);
  }

  static Future<List<Map<String, dynamic>>> getLogs({String? category, String? level}) async {
    final prefs = await SharedPreferences.getInstance();
    final logStrings = prefs.getStringList(_logKey) ?? [];
    
    final logs = logStrings.map((logString) {
      try {
        return jsonDecode(logString) as Map<String, dynamic>;
      } catch (e) {
        return {
          'timestamp': DateTime.now().toIso8601String(),
          'level': 'ERROR',
          'category': 'LOGGER',
          'message': 'Failed to parse log entry: $logString',
        };
      }
    }).toList();

    // Filter logs if category or level is specified
    var filteredLogs = logs;
    if (category != null) {
      filteredLogs = filteredLogs.where((log) => log['category'] == category).toList();
    }
    if (level != null) {
      filteredLogs = filteredLogs.where((log) => log['level'] == level).toList();
    }

    // Sort by timestamp (most recent first)
    filteredLogs.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
    
    return filteredLogs;
  }

  static Future<void> clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }

  // Convenience methods for different log levels
  static Future<void> info(String message, {String category = 'GENERAL'}) async {
    await log(message, level: 'INFO', category: category);
  }

  static Future<void> warning(String message, {String category = 'GENERAL'}) async {
    await log(message, level: 'WARNING', category: category);
  }

  static Future<void> error(String message, {String category = 'GENERAL'}) async {
    await log(message, level: 'ERROR', category: category);
  }

  // Specific logging methods for reading aloud functionality
  static Future<void> logReadingAloudEvent(String event, {String? details}) async {
    final message = details != null ? '$event: $details' : event;
    await log(message, level: 'INFO', category: 'READING_ALOUD');
  }

  static Future<void> logReadingAloudError(String error, {String? context}) async {
    final message = context != null ? '$error (Context: $context)' : error;
    await log(message, level: 'ERROR', category: 'READING_ALOUD');
  }

  static Future<void> logAISentMessage(String message) async {
    // Truncate very long messages for logging
    final truncatedMessage = message.length > 500 ? '${message.substring(0, 500)}...' : message;
    await log('AI Request: $truncatedMessage', level: 'INFO', category: 'AI_REQUEST');
  }

  static Future<void> logAIReceivedResponse(String response) async {
    // Truncate very long responses for logging
    final truncatedResponse = response.length > 500 ? '${response.substring(0, 500)}...' : response;
    await log('AI Response: $truncatedResponse', level: 'INFO', category: 'AI_RESPONSE');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.init();
  await _populateTestData();
  runApp(const MyApp());
}

Future<void> _populateTestData() async {
  final stories = DatabaseHelper.getStories();
  if (stories.isEmpty) {
    // Add sample stories for testing
    final sampleStories = [
      TextStory(
        author: 'Hans Christian Andersen',
        name: 'The Little Mermaid',
        language: 'English',
        theme: 'Fairy Tale',
        text: 'Once upon a time, there was a little mermaid who lived in the sea. She was the youngest of six sisters, and she was very curious about the world above the water...',
      ),
      TextStory(
        author: 'Brothers Grimm',
        name: 'Cinderella',
        language: 'English',
        theme: 'Fairy Tale',
        text: 'Once there was a girl called Cinderella. She lived with her wicked stepmother and two stepsisters. They treated her very badly...',
      ),
      TextStory(
        author: 'Charles Perrault',
        name: 'Sleeping Beauty',
        language: 'English',
        theme: 'Fairy Tale',
        text: 'Once upon a time, there was a king and queen who had a beautiful daughter named Aurora. On the day of her christening, she was cursed by an evil fairy...',
      ),
      TextStory(
        author: 'Lewis Carroll',
        name: 'Alice in Wonderland',
        language: 'English',
        theme: 'Adventure',
        text: 'Alice was beginning to get very tired of sitting by her sister on the bank, and of having nothing to do...',
      ),
      TextStory(
        author: 'J.K. Rowling',
        name: 'Harry Potter and the Philosopher\'s Stone',
        language: 'English',
        theme: 'Fantasy',
        text: 'Mr. and Mrs. Dursley, of number four, Privet Drive, were proud to say that they were perfectly normal, thank you very much...',
      ),
      TextStory(
        author: 'Mark Twain',
        name: 'The Adventures of Tom Sawyer',
        language: 'English',
        theme: 'Adventure',
        text: 'Tom Sawyer lived with his Aunt Polly, his cousin Mary, and his bother Sid. Tom was a mischievous boy...',
      ),
    ];

    for (final story in sampleStories) {
      DatabaseHelper.addStory(story);
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VT-Polyglot',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'VT-Polyglot'),
    );
  }
}

class AvailableAIModelsPage extends StatefulWidget {
  const AvailableAIModelsPage({super.key});

  @override
  _AvailableAIModelsPageState createState() => _AvailableAIModelsPageState();
}

class _AvailableAIModelsPageState extends State<AvailableAIModelsPage> {
  List<AIModel> aiModels = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAIModels();
  }

  void _loadAIModels() {
    setState(() {
      aiModels = DatabaseHelper.getAIModels();
    });
  }

  Future<void> _updateAIModels() async {
    setState(() => isLoading = true);

    try {
      // Get the API key from settings
      final prefs = await SharedPreferences.getInstance();
      final apiKey = prefs.getString('apiKey');

      if (apiKey == null || apiKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please set an AI API Key in Settings first')),
        );
        return;
      }

      // Call AI API to get available models
      final model = GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: apiKey);
      final content = [Content.text('List all available AI models from major providers like Google, OpenAI, Anthropic, etc. For each model, provide: name, provider, model_code, description, and capabilities (as array). Return as JSON array of objects.')];
      final response = await model.generateContent(content);
      final text = response.text;

      if (text != null) {
        try {
          // Clean the response text by removing markdown code blocks
          String cleanText = text.trim();
          if (cleanText.startsWith('```json')) {
            cleanText = cleanText.substring(7); // Remove ```json
          }
          if (cleanText.startsWith('```')) {
            cleanText = cleanText.substring(3); // Remove ```
          }
          if (cleanText.endsWith('```')) {
            cleanText = cleanText.substring(0, cleanText.length - 3); // Remove ```
          }
          cleanText = cleanText.trim();

          final List<dynamic> modelsList = jsonDecode(cleanText);
          
          // Clear existing models
          await DatabaseHelper.clearAIModels();
          
          // Add new models
          for (final modelData in modelsList) {
            final aiModel = AIModel(
              name: modelData['name'] ?? 'Unknown',
              provider: modelData['provider'] ?? 'Unknown',
              modelCode: modelData['model_code'] ?? modelData['modelCode'] ?? 'unknown',
              description: modelData['description'] ?? '',
              capabilities: List<String>.from(modelData['capabilities'] ?? []),
            );
            await DatabaseHelper.addAIModel(aiModel);
          }

          _loadAIModels();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI models updated successfully')),
          );
        } catch (e) {
          print('Error parsing AI models: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error parsing AI response')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No response from AI API')),
        );
      }
    } catch (e) {
      print('Error updating AI models: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating AI models: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available AI Models')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('Available AI Models', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : _updateAIModels,
                  child: isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (aiModels.isEmpty && !isLoading)
              const Text('No AI models available. Press Update to fetch from AI API.')
            else
              Expanded(
                child: ListView.builder(
                  itemCount: aiModels.length,
                  itemBuilder: (context, index) {
                    final model = aiModels[index];
                    return Card(
                      child: ListTile(
                        title: Text(model.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Provider: ${model.provider}'),
                            Text('Model Code: ${model.modelCode}'),
                            Text('Description: ${model.description}'),
                            Text('Capabilities: ${model.capabilities.join(', ')}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GrammarPage())),
              child: const Text('Grammar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WritingPage())),
              child: const Text('Writing'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReadingPage())),
              child: const Text('Reading'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListeningPage())),
              child: const Text('Listening'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
              child: const Text('Settings'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LibraryPage())),
              child: const Text('Library'),
            ),
          ],
        ),
      ),
    );
  }
}

class GrammarPage extends StatelessWidget {
  const GrammarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Grammar')),
      body: const Center(child: Text('Grammar Page - Coming Soon')),
    );
  }
}

class WritingPage extends StatelessWidget {
  const WritingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Writing')),
      body: const Center(child: Text('Writing Page - Coming Soon')),
    );
  }
}

class ReadingPage extends StatelessWidget {
  const ReadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reading')),
      body: const Center(child: Text('Reading Page - Coming Soon')),
    );
  }
}

class Story {
  String author;
  String theme;
  String name;
  bool selected;

  Story({required this.author, required this.theme, required this.name, this.selected = false});
}

class AIModelConfig {
  String function;
  String modelCode;
  String apiKey;

  AIModelConfig({
    required this.function,
    required this.modelCode,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() => {
    'function': function,
    'modelCode': modelCode,
    'apiKey': apiKey,
  };

  factory AIModelConfig.fromJson(Map<String, dynamic> json) => AIModelConfig(
    function: json['function'],
    modelCode: json['modelCode'],
    apiKey: json['apiKey'],
  );
}

class ListeningPage extends StatefulWidget {
  const ListeningPage({super.key});

  @override
  _ListeningPageState createState() => _ListeningPageState();
}

class _ListeningPageState extends State<ListeningPage> {
  List<Story> stories = [];
  SharedPreferences? prefs;
  String? learningLanguage;
  String? apiKey;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    learningLanguage = prefs?.getString('learningLanguage');
    apiKey = prefs?.getString('apiKey');
    if (learningLanguage != null && learningLanguage!.isNotEmpty && apiKey != null && apiKey!.isNotEmpty) {
      _fetchStories();
    }
  }

  Future<void> _fetchStories() async {
    if (learningLanguage == null || apiKey == null || apiKey!.isEmpty) return;

    final model = GenerativeModel(model: 'gemini-2.5-flash-lite', apiKey: apiKey!);
    final content = [Content.text('Find 5 short stories in $learningLanguage from free sources only. For each of the found stories, get author, theme, name, short content, and direct URL to the full story text. Got on the previous step result return as JSON array of objects with keys: author, theme, name, content and URL.')];
    final response = await model.generateContent(content);
    final text = response.text;
    print("response text: $text");
    if (text != null) {
      try {
        // Clean the response text by removing markdown code blocks
        String cleanText = text.trim();
        if (cleanText.startsWith('```json')) {
          cleanText = cleanText.substring(7); // Remove ```json
        }
        if (cleanText.startsWith('```')) {
          cleanText = cleanText.substring(3); // Remove ```
        }
        if (cleanText.endsWith('```')) {
          cleanText = cleanText.substring(0, cleanText.length - 3); // Remove ```
        }
        cleanText = cleanText.trim();

        final List<dynamic> storyList = jsonDecode(cleanText);
        setState(() {
          stories = storyList.map((s) => Story(author: s['author'] ?? '', theme: s['theme'] ?? '', name: s['name'] ?? '')).toList();
        });
      } catch (e) {
        // Handle parsing error
        print('Error parsing stories: $e');
      }
    } else {
      print('No response text');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listening')),
      body: stories.isEmpty
          ? Center(child: Text(apiKey == null || apiKey!.isEmpty ? 'Please set an AI API Key in Profile.' : 'No stories available. Please set a learning language in Profile.'))
          : SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Story author')),
                  DataColumn(label: Text('Theme')),
                  DataColumn(label: Text('Story name')),
                  DataColumn(label: Text('Selected')),
                ],
                rows: stories.map((story) => DataRow(
                  cells: [
                    DataCell(Text(story.author)),
                    DataCell(Text(story.theme)),
                    DataCell(Text(story.name)),
                    DataCell(Checkbox(
                      value: story.selected,
                      onChanged: (value) => setState(() => story.selected = value ?? false),
                    )),
                  ],
                )).toList(),
              ),
            ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? myLanguage;
  String? learningLanguage;
  String? apiKey;
  List<AIModelConfig> aiModelConfigs = [];

  SharedPreferences? prefs;

  final GlobalKey<DropdownSearchState<String>> myLanguageKey = GlobalKey();
  final GlobalKey<DropdownSearchState<String>> learningLanguageKey = GlobalKey();

  final TextEditingController apiKeyController = TextEditingController();

  final List<String> countries = [
    'American English',
    'Spanish',
    'French',
    'German',
    'Brazilian Portuguese',
    'Hindi',
    'Russian',
    'Italian',
    'British English',
    'Mexican Spanish',
    'Kazakh',
    'Ukrainian',
  ];

  final List<String> availableFunctions = [
    'default',
    'find story in internet',
    'text-to-speech',
    'speech-to-text',
    'translate text',
    'generate story',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    prefs = await SharedPreferences.getInstance();
    setState(() {
      myLanguage = prefs?.getString('myLanguage');
      learningLanguage = prefs?.getString('learningLanguage');
      apiKey = prefs?.getString('apiKey');
      apiKeyController.text = apiKey ?? '';
      _loadAIModelConfigs();
    });
  }

  void _loadAIModelConfigs() {
    final configsJson = prefs?.getStringList('aiModelConfigs') ?? [];
    aiModelConfigs = configsJson.map((json) => AIModelConfig.fromJson(jsonDecode(json))).toList();
    
    // If no configurations exist, add default configuration
    if (aiModelConfigs.isEmpty) {
      aiModelConfigs.add(AIModelConfig(
        function: 'default',
        modelCode: 'gemini-2.5-flash-lite',
        apiKey: '',
      ));
      _saveAIModelConfigs();
    }
  }

  Future<void> _saveAIModelConfigs() async {
    final configsJson = aiModelConfigs.map((config) => jsonEncode(config.toJson())).toList();
    await prefs?.setStringList('aiModelConfigs', configsJson);
  }

  Future<void> _saveMyLanguage(String? value) async {
    myLanguage = value;
    await prefs?.setString('myLanguage', value ?? '');
  }

  Future<void> _saveLearningLanguage(String? value) async {
    learningLanguage = value;
    await prefs?.setString('learningLanguage', value ?? '');
  }

  Future<void> _saveApiKey(String value) async {
    apiKey = value;
    await prefs?.setString('apiKey', value);
  }

  void _showAddAIModelConfigDialog() {
    final functionController = TextEditingController();
    final modelCodeController = TextEditingController();
    final apiKeyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add AI Model Config'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Function'),
                items: availableFunctions.map((function) => DropdownMenuItem(
                  value: function,
                  child: Text(function),
                )).toList(),
                onChanged: (value) => functionController.text = value ?? '',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelCodeController,
                decoration: const InputDecoration(labelText: 'AI Model Code'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (functionController.text.isEmpty || modelCodeController.text.isEmpty || apiKeyController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill in all fields')),
              );
              return;
            }

            final newConfig = AIModelConfig(
              function: functionController.text,
              modelCode: modelCodeController.text,
              apiKey: apiKeyController.text,
            );

            setState(() {
              aiModelConfigs.add(newConfig);
            });

            _saveAIModelConfigs();
            Navigator.pop(context);
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showAIModelConfigDetails(AIModelConfig config) {
    final functionController = TextEditingController(text: config.function);
    final modelCodeController = TextEditingController(text: config.modelCode);
    final apiKeyController = TextEditingController(text: config.apiKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Model Configuration Details'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: functionController.text,
                decoration: const InputDecoration(labelText: 'Function'),
                items: availableFunctions.map((function) => DropdownMenuItem(
                  value: function,
                  child: Text(function),
                )).toList(),
                onChanged: (value) => functionController.text = value ?? '',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelCodeController,
                decoration: const InputDecoration(labelText: 'AI Model Code'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (functionController.text.isEmpty || modelCodeController.text.isEmpty || apiKeyController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              final updatedConfig = AIModelConfig(
                function: functionController.text,
                modelCode: modelCodeController.text,
                apiKey: apiKeyController.text,
              );

              setState(() {
                final index = aiModelConfigs.indexOf(config);
                aiModelConfigs[index] = updatedConfig;
              });

              _saveAIModelConfigs();
              Navigator.pop(context);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _deleteAIModelConfig(AIModelConfig config) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete AI Model Config'),
        content: const Text('Are you sure you want to delete this configuration?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            setState(() => aiModelConfigs.remove(config));
            _saveAIModelConfigs();
            Navigator.pop(context);
          }, child: const Text('Delete')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Text('My language:'),
            DropdownSearch<String>(
              key: myLanguageKey,
              items: countries,
              selectedItem: myLanguage,
              onChanged: (value) {
                setState(() => myLanguage = value);
                _saveMyLanguage(value);
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select your language',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: const PopupProps.menu(
                showSearchBox: true,
              ),
            ),
            const SizedBox(height: 20),
            const Text('Learning language:'),
            DropdownSearch<String>(
              key: learningLanguageKey,
              items: countries,
              selectedItem: learningLanguage,
              onChanged: (value) {
                setState(() => learningLanguage = value);
                _saveLearningLanguage(value);
              },
              dropdownDecoratorProps: const DropDownDecoratorProps(
                dropdownSearchDecoration: InputDecoration(
                  labelText: 'Select learning language',
                  border: OutlineInputBorder(),
                ),
              ),
              popupProps: const PopupProps.menu(
                showSearchBox: true,
              ),
            ),
            const SizedBox(height: 20),
            const Text('AI API Key:'),
            TextField(
              controller: apiKeyController,
              decoration: const InputDecoration(
                labelText: 'Enter AI API Key',
                border: OutlineInputBorder(),
              ),
              onChanged: _saveApiKey,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AvailableAIModelsPage())),
              child: const Text('Available AI Models'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LogViewerPage())),
              child: const Text('View Application Logs'),
            ),
            const SizedBox(height: 40),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Model Configurations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showAddAIModelConfigDialog(),
                  child: const Text('Add New'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (aiModelConfigs.isEmpty)
              const Text('No AI model configurations added yet.')
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tap on a configuration to edit or delete it'),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: aiModelConfigs.length,
                    itemBuilder: (context, index) {
                      final config = aiModelConfigs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(config.function),
                          subtitle: Text('${config.modelCode}\nAPI Key: ${'*' * config.apiKey.length}'),
                          isThreeLine: true,
                          onTap: () => _showAIModelConfigDetails(config),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteAIModelConfig(config),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

Future<AIModelConfig?> getAIModelConfigForFunction(String function) async {
  final prefs = await SharedPreferences.getInstance();
  final configsJson = prefs.getStringList('aiModelConfigs') ?? [];
  final configs = configsJson.map((json) => AIModelConfig.fromJson(jsonDecode(json))).toList();
  
  // First try to find exact match
  final exactMatch = configs.where((config) => config.function == function).toList();
  if (exactMatch.isNotEmpty) {
    return exactMatch.first;
  }
  
  // If no exact match, return default
  final defaultConfig = configs.where((config) => config.function == 'default').toList();
  return defaultConfig.isNotEmpty ? defaultConfig.first : null;
}

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

class LibraryPage extends StatefulWidget {

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<TextStory> allStories = [];
  List<TextStory> filteredStories = [];
  String searchQuery = '';
  int currentPage = 0;
  final int itemsPerPage = 5;

  @override
  void initState() {
    super.initState();
    _loadStories();
  }

  void _loadStories() {
    setState(() {
      allStories = DatabaseHelper.getStories();
      _filterStories();
    });
  }

  void _filterStories() {
    if (searchQuery.isEmpty) {
      filteredStories = List.from(allStories);
    } else {
      filteredStories = allStories.where((story) =>
        story.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        story.author.toLowerCase().contains(searchQuery.toLowerCase()) ||
        story.theme.toLowerCase().contains(searchQuery.toLowerCase())
      ).toList();
    }
    currentPage = 0; // Reset to first page
  }

  List<TextStory> get _paginatedStories {
    int start = currentPage * itemsPerPage;
    int end = start + itemsPerPage;
    return filteredStories.sublist(start, end > filteredStories.length ? filteredStories.length : end);
  }

  void _showAddDialog() {
    TextEditingController authorController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    TextEditingController languageController = TextEditingController();
    TextEditingController themeController = TextEditingController();
    TextEditingController sourceUrlController = TextEditingController();
    TextEditingController textController = TextEditingController();

    Future<void> pickFile() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        if (file.bytes != null) {
          String content = String.fromCharCodes(file.bytes!);
          textController.text = content;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Story'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: authorController, decoration: const InputDecoration(labelText: 'Author')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: languageController, decoration: const InputDecoration(labelText: 'Language')),
              TextField(controller: themeController, decoration: const InputDecoration(labelText: 'Theme')),
              TextField(controller: sourceUrlController, decoration: const InputDecoration(labelText: 'Source URL')),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: textController, decoration: const InputDecoration(labelText: 'Text'), maxLines: 5),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_upload),
                    onPressed: pickFile,
                    tooltip: 'Load from file',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            TextStory newStory = TextStory(
              author: authorController.text,
              name: nameController.text,
              language: languageController.text,
              theme: themeController.text,
              sourceUrl: sourceUrlController.text.isEmpty ? null : sourceUrlController.text,
              text: textController.text,
            );
            DatabaseHelper.addStory(newStory);
            _loadStories();
            Navigator.pop(context);
          }, child: const Text('Add')),
        ],
      ),
    );
  }

  void _showEditDialog(TextStory story) {
    TextEditingController authorController = TextEditingController(text: story.author);
    TextEditingController nameController = TextEditingController(text: story.name);
    TextEditingController languageController = TextEditingController(text: story.language);
    TextEditingController themeController = TextEditingController(text: story.theme);
    TextEditingController sourceUrlController = TextEditingController(text: story.sourceUrl ?? '');
    TextEditingController textController = TextEditingController(text: story.text);

    Future<void> pickFile() async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        if (file.bytes != null) {
          String content = String.fromCharCodes(file.bytes!);
          textController.text = content;
        }
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Story'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: authorController, decoration: const InputDecoration(labelText: 'Author')),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: languageController, decoration: const InputDecoration(labelText: 'Language')),
              TextField(controller: themeController, decoration: const InputDecoration(labelText: 'Theme')),
              TextField(controller: sourceUrlController, decoration: const InputDecoration(labelText: 'Source URL')),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: textController, decoration: const InputDecoration(labelText: 'Text'), maxLines: 5),
                  ),
                  IconButton(
                    icon: const Icon(Icons.file_upload),
                    onPressed: pickFile,
                    tooltip: 'Load from file',
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            story.author = authorController.text;
            story.name = nameController.text;
            story.language = languageController.text;
            story.theme = themeController.text;
            story.sourceUrl = sourceUrlController.text.isEmpty ? null : sourceUrlController.text;
            story.text = textController.text;
            DatabaseHelper.updateStory(story);
            _loadStories();
            Navigator.pop(context);
          }, child: const Text('Save')),
        ],
      ),
    );
  }

  void _showViewDialog(TextStory story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(story.name),
        content: SingleChildScrollView(child: Text(story.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  void _deleteStory(TextStory story) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Story'),
        content: const Text('Are you sure you want to delete this story?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () {
            if (story.id != null) DatabaseHelper.deleteStory(story.id!);
            _loadStories();
            Navigator.pop(context);
          }, child: const Text('Delete')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPages = (filteredStories.length / itemsPerPage).ceil();

    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search by title, author, or theme',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value;
                        _filterStories();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: _showAddDialog, child: const Text('Add New')),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _paginatedStories.length,
                itemBuilder: (context, index) {
                  TextStory story = _paginatedStories[index];
                  String shortContent = story.text.length > 100 ? '${story.text.substring(0, 100)}...' : story.text;
                  return Card(
                    child: ListTile(
                      title: Text(story.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Author: ${story.author}'),
                          Text('Theme: ${story.theme}'),
                          Text('Short Content: $shortContent'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.record_voice_over),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadingAloudPage(selectedStory: story),
                              ),
                            ),
                            tooltip: 'Read Aloud',
                          ),
                          IconButton(icon: const Icon(Icons.visibility), onPressed: () => _showViewDialog(story)),
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditDialog(story)),
                          IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteStory(story)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (totalPages > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: currentPage > 0 ? () => setState(() => currentPage--) : null,
                  ),
                  Text('${currentPage + 1} / $totalPages'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: currentPage < totalPages - 1 ? () => setState(() => currentPage++) : null,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class LogViewerPage extends StatefulWidget {
  const LogViewerPage({super.key});

  @override
  _LogViewerPageState createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<LogViewerPage> {
  List<Map<String, dynamic>> logs = [];
  bool isLoading = true;
  String? selectedCategory;
  String? selectedLevel;

  final List<String> categories = ['ALL', 'READING_ALOUD', 'AI_REQUEST', 'AI_RESPONSE', 'GENERAL'];
  final List<String> levels = ['ALL', 'INFO', 'WARNING', 'ERROR'];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => isLoading = true);

    try {
      final allLogs = await AppLogger.getLogs(
        category: selectedCategory == 'ALL' ? null : selectedCategory,
        level: selectedLevel == 'ALL' ? null : selectedLevel,
      );

      setState(() {
        logs = allLogs;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load logs: $e')),
      );
    }
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs'),
        content: const Text('Are you sure you want to clear all application logs? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AppLogger.clearLogs();
      setState(() => logs = []);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All logs cleared')),
      );
    }
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'ERROR':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      case 'INFO':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
             '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: logs.isNotEmpty ? _clearLogs : null,
            tooltip: 'Clear All Logs',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filters
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedCategory ?? 'ALL',
                    items: categories.map((category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => selectedCategory = value);
                      _loadLogs();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Level',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedLevel ?? 'ALL',
                    items: levels.map((level) => DropdownMenuItem(
                      value: level,
                      child: Text(level),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => selectedLevel = value);
                      _loadLogs();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${logs.length} log entries',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Logs list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : logs.isEmpty
                      ? const Center(child: Text('No logs found'))
                      : ListView.builder(
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getLevelColor(log['level']),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            log['level'],
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          log['category'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _formatTimestamp(log['timestamp']),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      log['message'],
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}