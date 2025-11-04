import 'dart:async';
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'app_logger.dart';
import '../models/ai_model_config.dart';
import '../utils/ai_model_utils.dart';

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