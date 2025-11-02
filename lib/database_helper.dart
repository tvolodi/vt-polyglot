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

class DatabaseHelper {
  static const String _boxName = 'storyLibrary';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  static Box get _box => Hive.box(_boxName);

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
}