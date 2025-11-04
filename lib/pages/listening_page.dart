import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import '../models/story.dart';

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