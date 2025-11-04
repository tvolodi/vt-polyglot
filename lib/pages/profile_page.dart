import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/ai_model_config.dart';
import 'available_ai_models_page.dart';
import 'log_viewer_page.dart';

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