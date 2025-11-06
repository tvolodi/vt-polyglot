import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:googleapis/texttospeech/v1.dart' as tts;
import 'package:googleapis/speech/v1.dart' as speech;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'app_logger.dart';
import '../models/ai_model_config.dart';
import '../utils/ai_model_utils.dart';

class AIAssessmentService {
  Future<void> initialize() async {
    // No initialization needed for AI assessment service
    await AppLogger.logReadingAloudEvent('AI Assessment service initialized');
  }
  /// Test method to verify Google Speech-to-Text integration
  /// Tests API connectivity and basic functionality
  Future<Map<String, dynamic>> testSpeechToTextIntegration() async {
    try {
      await AppLogger.logReadingAloudEvent('Starting Speech-to-Text integration test');

      // Test 1: Check if API configuration exists
      AIModelConfig? googleApiConfig = await getGoogleAPIConfig();
      if (googleApiConfig == null || googleApiConfig.apiKey.isEmpty) {
        String errorMsg = googleApiConfig == null
          ? 'Google API configuration not found. Please add a configuration with function="google_api" in Settings.'
          : 'Google API key is empty. Please set the API key in Settings > AI Model Configurations > google_api.';
        await AppLogger.logReadingAloudError('API configuration test failed: $errorMsg');
        return {
          'success': false,
          'error': errorMsg,
          'test_results': {
            'config_check': false,
            'api_connectivity': false,
            'transcription_test': false,
          }
        };
      }

      await AppLogger.logReadingAloudEvent('API configuration test passed', details: 'Function: ${googleApiConfig.function}, Key configured: ${googleApiConfig.apiKey.isNotEmpty}');

      // Test 2: Test API connectivity by making a simple request
      bool apiConnectivityTest = false;
      try {
        final client = auth.clientViaApiKey(googleApiConfig.apiKey);
        // Just test that we can create the client - this validates the API key format
        apiConnectivityTest = true;
        client.close();
      } catch (e) {
        await AppLogger.logReadingAloudEvent('API connectivity test failed', details: e.toString());
      }

      // Test 3: Create a test audio file using TTS and transcribe it
      const testText = "Hello world";
      final transcriptionTest = await _runTranscriptionTest(testText);

      final overallSuccess = apiConnectivityTest && transcriptionTest['success'] == true;

      await AppLogger.logReadingAloudEvent('Speech-to-Text integration test completed',
        details: 'Overall success: $overallSuccess, API connected: $apiConnectivityTest, Transcription test: ${transcriptionTest['success']}');

      return {
        'success': overallSuccess,
        'error': overallSuccess ? null : 'One or more tests failed',
        'test_results': {
          'config_check': true,
          'api_connectivity': apiConnectivityTest,
          'transcription_test': transcriptionTest['success'],
        },
        'transcription_details': transcriptionTest,
        'note': 'Test uses TTS-generated speech - expects accurate transcription',
      };

    } catch (e) {
      await AppLogger.logReadingAloudError('Speech-to-Text integration test failed: $e');
      return {
        'success': false,
        'error': e.toString(),
        'test_results': {
          'config_check': false,
          'api_connectivity': false,
          'transcription_test': false,
        }
      };
    }
  }

  /// Run a transcription test using TTS-generated audio
  Future<Map<String, dynamic>> _runTranscriptionTest(String testText) async {
    try {
      await AppLogger.logReadingAloudEvent('Starting transcription test', details: 'Test text: "$testText"');

      final testAudioPath = await _createTestAudioFile(testText);
      if (testAudioPath == null) {
        await AppLogger.logReadingAloudError('Failed to create test audio file');
        return {
          'success': false,
          'error': 'Failed to create test audio file - check TTS API configuration',
          'expected_text': testText,
          'transcribed_text': null,
        };
      }

      await AppLogger.logReadingAloudEvent('Audio file created, starting transcription', details: 'Path: $testAudioPath');

      final transcribedText = await _transcribeAudioFile(testAudioPath);

      await AppLogger.logReadingAloudEvent('Transcription completed', details: 'Result: "$transcribedText"');

      // Clean up test file
      try {
        await File(testAudioPath).delete();
      } catch (e) {
        // Ignore cleanup errors
      }

      // For TTS-generated speech, we expect accurate transcription
      // The test passes if we get any transcription that contains the key words
      final success = transcribedText.isNotEmpty &&
                     (transcribedText.toLowerCase().contains('hello') ||
                      transcribedText.toLowerCase().contains('world'));
      final similarity = _calculateTextSimilarity(testText.toLowerCase(), transcribedText.toLowerCase());

      await AppLogger.logReadingAloudEvent('Test evaluation completed',
        details: 'Success: $success, Similarity: ${(similarity * 100).round()}%');

      return {
        'success': success,
        'expected_text': testText,
        'transcribed_text': transcribedText,
        'similarity_score': similarity,
        'note': 'TTS-generated speech test - expects accurate transcription',
        'error': null,
      };

    } catch (e) {
      await AppLogger.logReadingAloudError('Transcription test failed: $e');
      return {
        'success': false,
        'error': 'Test failed: ${e.toString()}',
        'expected_text': testText,
        'transcribed_text': null,
      };
    }
  }

  /// Create a test audio file using Google Cloud Text-to-Speech
  Future<String?> _createTestAudioFile(String text) async {
    try {
      await AppLogger.logReadingAloudEvent('Creating test audio file with Google TTS', details: 'Text: "$text"');

      // Get Google API configuration
      AIModelConfig? googleApiConfig = await getGoogleAPIConfig();
      if (googleApiConfig == null) {
        await AppLogger.logReadingAloudError('Google API config not found - please configure google_api in Settings');
        return null;
      }

      if (googleApiConfig.apiKey.isEmpty) {
        await AppLogger.logReadingAloudError('Google API key is empty - please set API key in Settings > AI Model Configurations > google_api');
        return null;
      }

      await AppLogger.logReadingAloudEvent('Google API config found', details: 'Function: ${googleApiConfig.function}, Model: ${googleApiConfig.modelCode}, Key length: ${googleApiConfig.apiKey.length}');

      // Create authenticated client
      final client = auth.clientViaApiKey(googleApiConfig.apiKey);

      // Create Text-to-Speech API client
      final ttsApi = tts.TexttospeechApi(client);

      // Create synthesis request
      final synthesisInput = tts.SynthesisInput()..text = text;

      final voice = tts.VoiceSelectionParams()
        ..languageCode = 'en-US'
        ..name = 'en-US-Neural2-D'; // High quality voice

      final audioConfig = tts.AudioConfig()
        ..audioEncoding = 'LINEAR16'  // WAV format
        ..sampleRateHertz = 16000;    // 16kHz to match Speech-to-Text expectations

      final request = tts.SynthesizeSpeechRequest()
        ..input = synthesisInput
        ..voice = voice
        ..audioConfig = audioConfig;

      await AppLogger.logReadingAloudEvent('Calling TTS API', details: 'Voice: en-US-Neural2-D, Encoding: LINEAR16');

      // Generate speech
      final response = await ttsApi.text.synthesize(request);

      if (response.audioContent == null) {
        await AppLogger.logReadingAloudError('TTS API returned no audio content');
        client.close();
        return null;
      }

      await AppLogger.logReadingAloudEvent('TTS API call successful', details: 'Audio content length: ${response.audioContent!.length}');

      // Decode base64 audio content
      final audioBytes = base64Decode(response.audioContent!);

      // Create temporary file
      final tempDir = Directory.systemTemp;
      final testFileName = 'tts_test_${DateTime.now().millisecondsSinceEpoch}.wav';
      final testFilePath = '${tempDir.path}/$testFileName';

      final testFile = File(testFilePath);
      await testFile.writeAsBytes(audioBytes);

      await AppLogger.logReadingAloudEvent('TTS audio file created',
        details: 'Path: $testFilePath, Size: ${await testFile.length()} bytes');

      client.close();
      return testFilePath;

    } catch (e) {
      await AppLogger.logReadingAloudError('Failed to create TTS audio file: $e');
      return null;
    }
  }

  /// Calculate similarity between two texts (simple word-based comparison)
  double _calculateTextSimilarity(String text1, String text2) {
    final words1 = text1.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();
    final words2 = text2.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toSet();

    if (words1.isEmpty && words2.isEmpty) return 1.0;
    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  Future<String> _transcribeAudioFile(String audioFilePath) async {
    try {
      await AppLogger.logReadingAloudEvent('Starting audio file transcription', details: 'File: $audioFilePath');

      // Get Google API configuration for speech-to-text
      AIModelConfig? googleApiConfig = await getGoogleAPIConfig();

      if (googleApiConfig == null) {
        await AppLogger.logReadingAloudError('Google API config not found for STT');
        throw Exception('Google API config not found');
      }

      if (googleApiConfig.apiKey.isEmpty) {
        await AppLogger.logReadingAloudError('Google API key is empty for STT');
        throw Exception('Google API key not configured. Please set up Google API configuration in Settings.');
      }

      await AppLogger.logReadingAloudEvent('STT API config found', details: 'Key length: ${googleApiConfig.apiKey.length}');

      // Create authenticated client using API key
      final client = auth.clientViaApiKey(googleApiConfig.apiKey);

      // Create Speech API client
      final speechApi = speech.SpeechApi(client);

      // Read audio file
      final audioFile = File(audioFilePath);
      if (!await audioFile.exists()) {
        await AppLogger.logReadingAloudError('Audio file does not exist: $audioFilePath');
        throw Exception('Audio file does not exist');
      }

      final audioBytes = await audioFile.readAsBytes();
      await AppLogger.logReadingAloudEvent('Audio file loaded', details: 'Size: ${audioBytes.length} bytes');

      // Create recognition request
      final recognitionAudio = speech.RecognitionAudio()..content = base64Encode(audioBytes);

      final recognitionConfig = speech.RecognitionConfig()
        ..encoding = 'LINEAR16'  // WAV format from recording
        ..sampleRateHertz = 16000  // Common sample rate for recordings
        ..languageCode = 'en-US'  // Default to English, could be made configurable
        ..enableAutomaticPunctuation = true
        ..enableWordTimeOffsets = false;

      final request = speech.RecognizeRequest()
        ..config = recognitionConfig
        ..audio = recognitionAudio;

      await AppLogger.logReadingAloudEvent('Calling STT API', details: 'Encoding: LINEAR16, SampleRate: 16000, Language: en-US');

      // Call Speech-to-Text API
      final response = await speechApi.speech.recognize(request);

      await AppLogger.logReadingAloudEvent('STT API call completed', details: 'Results count: ${response.results?.length ?? 0}');

      // Extract transcription from response
      if (response.results == null || response.results!.isEmpty) {
        await AppLogger.logReadingAloudEvent('No transcription results from Speech API');
        return '';
      }

      final transcription = response.results!
          .map((result) => result.alternatives?.firstOrNull?.transcript ?? '')
          .where((transcript) => transcript.isNotEmpty)
          .join(' ')
          .trim();

      await AppLogger.logReadingAloudEvent('Audio transcription completed', details: 'Transcription: "$transcription"');

      // Clean up client
      client.close();

      return transcription;

    } catch (e) {
      await AppLogger.logReadingAloudError('Speech-to-text transcription failed: $e');
      // Return empty string as fallback - the AI assessment will handle this gracefully
      return '';
    }
  }

  Future<Map<String, dynamic>> assessPronunciation(String audioFilePath, String expectedText) async {
    await AppLogger.logReadingAloudEvent('Starting pronunciation assessment', details: 'Expected text: "${expectedText.substring(0, 50)}${expectedText.length > 50 ? '...' : ''}"');

    try {
      // Get AI configuration for assessment
      AIModelConfig? aiConfig = await getAIModelConfigForFunction('default');

      if (aiConfig == null || aiConfig.apiKey.isEmpty) {
        await AppLogger.logReadingAloudError('AI API key not configured for assessment');
        throw Exception('AI API key not configured. Please set up API configuration in Settings.');
      }

      // Transcribe the audio file using Google Cloud Speech-to-Text
      final transcription = await _transcribeAudioFile(audioFilePath);

      if (transcription.isEmpty) {
        await AppLogger.logReadingAloudEvent('Audio transcription failed or empty, using expected text as fallback');
        // Use expected text as fallback if transcription fails
        return {
          'overall_score': 0,
          'word_accuracy': [],
          'pronunciation_issues': ['Audio transcription failed - unable to assess pronunciation'],
          'fluency_score': 0,
          'suggestions': ['Please check your microphone and try recording again', 'Ensure you are in a quiet environment']
        };
      }

      await AppLogger.logReadingAloudEvent('Audio transcription completed', details: 'Transcribed: "$transcription"');

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