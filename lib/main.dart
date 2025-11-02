import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.init();
  runApp(const MyApp());
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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GrammarPage())),
              child: const Text('Grammar'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WritingPage())),
              child: const Text('Writing'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReadingPage())),
              child: const Text('Reading'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ListeningPage())),
              child: const Text('Listening'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage())),
              child: const Text('Profile'),
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
        final List<dynamic> storyList = jsonDecode(text);
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
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
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
          ],
        ),
      ),
    );
  }
}