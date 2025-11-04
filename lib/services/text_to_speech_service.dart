import 'package:flutter_tts/flutter_tts.dart';

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