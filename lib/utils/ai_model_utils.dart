import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ai_model_config.dart';

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

Future<AIModelConfig?> getGoogleAPIConfig() async {
  return getAIModelConfigForFunction('google_api');
}