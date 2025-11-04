import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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