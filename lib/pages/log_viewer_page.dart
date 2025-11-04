import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_logger.dart';

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

  Future<void> _copyAllLogs() async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No logs to copy')),
      );
      return;
    }

    final allLogsText = logs.map((log) {
      return '''
[${log['level']}] ${log['category']} - ${_formatTimestamp(log['timestamp'])}
${log['message']}
${log['details'] != null ? 'Details: ${log['details']}' : ''}
'''.trim();
    }).join('\n\n---\n\n');

    await Clipboard.setData(ClipboardData(text: allLogsText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All logs copied to clipboard')),
    );
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
            icon: const Icon(Icons.copy_all),
            onPressed: logs.isNotEmpty ? _copyAllLogs : null,
            tooltip: 'Copy All Logs',
          ),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
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
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
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
            ),
            const SizedBox(height: 16),
            SelectableText(
              '${logs.length} log entries',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Logs list
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : logs.isEmpty
                      ? const Center(child: SelectableText('No logs found'))
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
                                        SelectableText(
                                          log['category'],
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const Spacer(),
                                        SelectableText(
                                          _formatTimestamp(log['timestamp']),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy, size: 16),
                                          onPressed: () async {
                                            final fullLogText = '''
[${log['level']}] ${log['category']} - ${_formatTimestamp(log['timestamp'])}
${log['message']}
${log['details'] != null ? '\nDetails: ${log['details']}' : ''}
'''.trim();
                                            await Clipboard.setData(ClipboardData(text: fullLogText));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Log copied to clipboard')),
                                            );
                                          },
                                          tooltip: 'Copy full log entry',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
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