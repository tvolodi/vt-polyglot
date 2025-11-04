import 'package:hive_flutter/hive_flutter.dart';

class TextStory {
  int? id;
  String author;
  String name;
  String language;
  String theme;
  String? sourceUrl;
  String text;

  TextStory({
    this.id,
    required this.author,
    required this.name,
    required this.language,
    required this.theme,
    this.sourceUrl,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'author': author,
      'name': name,
      'language': language,
      'theme': theme,
      'sourceUrl': sourceUrl,
      'text': text,
    };
  }

  factory TextStory.fromMap(Map<String, dynamic> map) {
    return TextStory(
      id: map['id'],
      author: map['author'],
      name: map['name'],
      language: map['language'],
      theme: map['theme'],
      sourceUrl: map['sourceUrl'],
      text: map['text'],
    );
  }
}

class AIModel {
  int? id;
  String name;
  String provider;
  String modelCode;
  String description;
  List<String> capabilities;

  AIModel({
    this.id,
    required this.name,
    required this.provider,
    required this.modelCode,
    required this.description,
    required this.capabilities,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'provider': provider,
      'modelCode': modelCode,
      'description': description,
      'capabilities': capabilities,
    };
  }

  factory AIModel.fromMap(Map<String, dynamic> map) {
    return AIModel(
      id: map['id'],
      name: map['name'],
      provider: map['provider'],
      modelCode: map['modelCode'],
      description: map['description'],
      capabilities: List<String>.from(map['capabilities'] ?? []),
    );
  }
}

class DatabaseHelper {
  static const String _boxName = 'storyLibrary';
  static const String _aiModelsBoxName = 'aiModels';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
    await Hive.openBox(_aiModelsBoxName);
  }

  static Box get _box => Hive.box(_boxName);
  static Box get _aiModelsBox => Hive.box(_aiModelsBoxName);

  static Future<void> addStory(TextStory story) async {
    int id = _box.length;
    story.id = id;
    await _box.put(id, story.toMap());
  }

  static List<TextStory> getStories() {
    return _box.values.map((e) => TextStory.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> updateStory(TextStory story) async {
    if (story.id != null) {
      await _box.put(story.id, story.toMap());
    }
  }

  static Future<void> deleteStory(int id) async {
    await _box.delete(id);
  }

  static Future<void> addAIModel(AIModel model) async {
    int id = _aiModelsBox.length;
    model.id = id;
    await _aiModelsBox.put(id, model.toMap());
  }

  static List<AIModel> getAIModels() {
    return _aiModelsBox.values.map((e) => AIModel.fromMap(Map<String, dynamic>.from(e))).toList();
  }

  static Future<void> updateAIModel(AIModel model) async {
    if (model.id != null) {
      await _aiModelsBox.put(model.id, model.toMap());
    }
  }

  static Future<void> deleteAIModel(int id) async {
    await _aiModelsBox.delete(id);
  }

  static Future<void> clearAIModels() async {
    await _aiModelsBox.clear();
  }
}