import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'pages/my_home_page.dart';

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