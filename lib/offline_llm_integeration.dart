import 'dart:io';
import 'package:cactus/cactus.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class ModelService {
  late final CactusLM _llm;

  Future<void> initModel() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelFile = File('${dir.path}/tinyllama.gguf');

    // Copy model from assets to local storage (once)
    if (!await modelFile.exists()) {
      final byteData = await rootBundle.load('assets/model/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf');
      await modelFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    // Initialize the model from local path
    _llm = await CactusLM.init(
      modelUrl: modelFile.path,
      contextSize: 512,
    );
  }

  Future<String> runPrompt(String prompt) async {
    final messages = [
      ChatMessage(role: 'system', content: 'You are a helpful assistant.'),
      ChatMessage(role: 'user', content: prompt),
    ];
    final result = await _llm.completion(messages, maxTokens: 100);
    return result.text.trim();
  }
}
