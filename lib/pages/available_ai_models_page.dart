import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import '../database_helper.dart';

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