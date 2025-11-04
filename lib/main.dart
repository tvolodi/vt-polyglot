import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:file_picker/file_picker.dart';
import 'database_helper.dart';

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
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LibraryPage())),
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

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

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