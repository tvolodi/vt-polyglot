import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:vt_polyglot/database_helper.dart';

void main() {
  setUpAll(() async {
    // Initialize Hive for testing with in-memory
    Hive.init(null); // Use in-memory
    await DatabaseHelper.init();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  test('Add and get stories', () {
    final story = TextStory(
      author: 'Test Author',
      name: 'Test Name',
      language: 'English',
      theme: 'Test Theme',
      text: 'Test Text',
    );

    DatabaseHelper.addStory(story);
    final stories = DatabaseHelper.getStories();

    expect(stories.length, 1);
    expect(stories[0].author, 'Test Author');
    expect(stories[0].name, 'Test Name');
  });

  test('Update story', () {
    final story = TextStory(
      author: 'Test Author',
      name: 'Test Name',
      language: 'English',
      theme: 'Test Theme',
      text: 'Test Text',
    );

    DatabaseHelper.addStory(story);
    final stories = DatabaseHelper.getStories();
    final firstStory = stories[0];
    firstStory.name = 'Updated Name';
    DatabaseHelper.updateStory(firstStory);

    final updatedStories = DatabaseHelper.getStories();
    expect(updatedStories[0].name, 'Updated Name');
  });

  test('Delete story', () {
    final story = TextStory(
      author: 'Test Author',
      name: 'Test Name',
      language: 'English',
      theme: 'Test Theme',
      text: 'Test Text',
    );

    DatabaseHelper.addStory(story);
    final stories = DatabaseHelper.getStories();
    final firstStory = stories[0];
    DatabaseHelper.deleteStory(firstStory.id!);

    final remainingStories = DatabaseHelper.getStories();
    expect(remainingStories.length, 0);
  });
}