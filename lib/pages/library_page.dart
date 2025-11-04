import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../database_helper.dart';
import 'reading_aloud_page.dart';

class LibraryPage extends StatefulWidget {
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
                          IconButton(
                            icon: const Icon(Icons.record_voice_over),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReadingAloudPage(selectedStory: story),
                              ),
                            ),
                            tooltip: 'Read Aloud',
                          ),
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