import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cactus/cactus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On-Device LLM Chat',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: LLMChatScreen(),
    );
  }
}

class LLMChatScreen extends StatefulWidget {
  @override
  State<LLMChatScreen> createState() => _LLMChatScreenState();
}

class _LLMChatScreenState extends State<LLMChatScreen> {
  CactusLM? _lm;
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  bool _isLoading = true;
  String _loadingStatus = 'Initializing...';
  String? _errorMessage;

  // List of alternative models to try
  final List<Map<String, dynamic>> _models = [
    // {
    //   'name': 'TinyLlama 1.1B (Small)',
    //   'url':
    //       'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    //   'context': 2048,
    // },
    // {
    //   'name': 'Phi-2 2.7B (Medium)',
    //   'url':
    //       'https://huggingface.co/microsoft/phi-2-gguf/resolve/main/phi-2.Q4_K_M.gguf',
    //   'context': 2048,
    // },
    {
      'name': 'Gemma 2B (Original)',
      'url':
          'https://huggingface.co/codegood/gemma-2b-it-Q4_K_M-GGUF/resolve/main/gemma-2b-it.Q4_K_M.gguf',
      'context': 2048,
    },
  ];

  int _currentModelIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    if (_currentModelIndex >= _models.length) {
      setState(() {
        _errorMessage =
            'All models failed to load. Please check your device compatibility.';
        _isLoading = false;
      });
      return;
    }

    final model = _models[_currentModelIndex];

    try {
      setState(() {
        _loadingStatus = 'Testing network connection...';
        _errorMessage = null;
      });

      // Test network connectivity first
      await _testNetworkConnectivity();

      setState(() {
        _loadingStatus = 'Loading ${model['name']}...';
      });

      print('Attempting to load model: ${model['name']}');
      print('Model URL: ${model['url']}');
      print('Platform: ${Platform.operatingSystem}');
      print('Architecture: ${Platform.version}');
      _lm = await CactusLM.init(
        modelUrl: model['url'],
        contextSize: model['context'],

        onProgress: (progress, status, isError) {
          setState(() {
            _loadingStatus =
                '${model['name']}: $status (${((progress ?? 0) * 100).toStringAsFixed(1)}%)';
          });
          print('Progress: $status (${(progress ?? 0) * 100}%)');

          if (isError) {
            print('Error during loading: $status');
          }
        },
      );

      setState(() {
        _isLoading = false;
        _loadingStatus = '${model['name']} loaded successfully!';
      });

      print('Model loaded successfully: ${model['name']}');
    } catch (e) {
      print('Model loading error for ${model['name']}: $e');
      print('Error type: ${e.runtimeType}');

      // Check if it's a network error
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        setState(() {
          _errorMessage =
              'Network Error: Cannot connect to Hugging Face.\n\nPlease check:\n• Internet connection\n• VPN settings\n• Firewall restrictions\n\nError: $e';
          _isLoading = false;
        });
        return;
      }

      // Try next model
      _currentModelIndex++;
      if (_currentModelIndex < _models.length) {
        print('Trying next model...');
        await _loadModel();
      } else {
        setState(() {
          _errorMessage = 'All models failed to load. Last error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendPrompt() async {
    if (_controller.text.trim().isEmpty || _lm == null) return;

    setState(() => _response = 'Thinking...');
    final userInput = _controller.text.trim();
    _controller.clear();

    try {
      final result = await _lm!.completion(
        [ChatMessage(role: 'user', content: userInput)],
        maxTokens: 100,
        temperature: 0.7,
      );
      setState(() => _response = result.text);
    } catch (e) {
      setState(() => _response = 'Error: $e');
    }
  }

  Future<void> _retryLoading() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentModelIndex = 0; // Reset to first model
    });
    await _loadModel();
  }

  Future<void> _testNetworkConnectivity() async {
    try {
      print('Testing network connectivity...');

      // Test basic connectivity
      final result = await InternetAddress.lookup('huggingface.co');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('Network connectivity: OK');
      } else {
        throw Exception('No network connectivity');
      }

      // Test HTTP connection
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse('https://huggingface.co'));
      final response = await request.close();
      print('HTTP test: Status ${response.statusCode}');
      client.close();
    } catch (e) {
      print('Network connectivity test failed: $e');
      throw Exception('Network connectivity failed: $e');
    }
  }

  Future<void> _checkSystemInfo() async {
    final info = StringBuffer();
    info.writeln('Platform: ${Platform.operatingSystem}');
    info.writeln('Version: ${Platform.version}');
    info.writeln('Locale: ${Platform.localeName}');

    try {
      final directory = await getApplicationDocumentsDirectory();
      info.writeln('App Dir: ${directory.path}');
    } catch (e) {
      info.writeln('App Dir Error: $e');
    }

    setState(() {
      _response = info.toString();
    });
  }

  @override
  void dispose() {
    _lm?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(_loadingStatus, textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('Model ${_currentModelIndex + 1} of ${_models.length}'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Error Loading Model',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _retryLoading,
                    child: Text('Retry'),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _checkSystemInfo,
                    child: Text('System Info'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('On-Device LLM Chat'),
        actions: [
          IconButton(icon: Icon(Icons.info), onPressed: _checkSystemInfo),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              'Using: ${_models[_currentModelIndex]['name']}',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Ask something...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _sendPrompt(),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _lm != null ? _sendPrompt : null,
              child: Text('Send'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_response, style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
