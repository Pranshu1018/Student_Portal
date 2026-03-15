import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

// API Service Provider for code execution
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class CodePracticeScreen extends ConsumerStatefulWidget {
  final int topicId;
  final String topicTitle;

  const CodePracticeScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  ConsumerState<CodePracticeScreen> createState() => _CodePracticeScreenState();
}

class _CodePracticeScreenState extends ConsumerState<CodePracticeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _inputController = TextEditingController();
  String _selectedLanguage = 'python';
  String _output = '';
  bool _isRunning = false;

  final Map<String, String> _languageTemplates = {
    'python': '# Write your Python code here\ndef solution():\n    # Your code\n    pass\n\nsolution()',
    'java': 'public class Main {\n    public static void main(String[] args) {\n        // Your code here\n    }\n}',
    'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    // Your code here\n    return 0;\n}',
    'c': '#include <stdio.h>\n\nint main() {\n    // Your code here\n    return 0;\n}',
    'javascript': '// Write your JavaScript code here\nfunction solution() {\n    // Your code\n}\n\nsolution();',
  };

  @override
  void initState() {
    super.initState();
    _codeController.text = _languageTemplates['python']!;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _changeLanguage(String? language) {
    if (language != null) {
      setState(() {
        _selectedLanguage = language;
        _codeController.text = _languageTemplates[language]!;
      });
    }
  }

  Future<void> _runCode() async {
    setState(() {
      _isRunning = true;
      _output = 'Running code...';
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.executeCode(
        _codeController.text,
        _selectedLanguage,
        [
          {
            'input': _inputController.text,
            'expected_output': '',
          }
        ],
      );

      setState(() {
        if (result['success'] == true) {
          final results = result['results'] as List;
          if (results.isNotEmpty) {
            _output = results[0]['actual_output'] ?? 'No output';
            if (results[0]['error'] != null) {
              _output = 'Error:\n${results[0]['error']}';
            }
          } else {
            _output = 'No output';
          }
        } else {
          _output = 'Error: ${result['error'] ?? 'Unknown error'}';
        }
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.topicTitle),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          // Language Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: _selectedLanguage,
              dropdownColor: AppColors.primaryBlue,
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
              items: [
                DropdownMenuItem(value: 'python', child: Text('Python')),
                DropdownMenuItem(value: 'java', child: Text('Java')),
                DropdownMenuItem(value: 'cpp', child: Text('C++')),
                DropdownMenuItem(value: 'c', child: Text('C')),
                DropdownMenuItem(value: 'javascript', child: Text('JavaScript')),
              ],
              onChanged: _changeLanguage,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Code Editor
          Expanded(
            flex: 3,
            child: Container(
              color: const Color(0xFF272822),
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _codeController,
                maxLines: null,
                expands: true,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  color: Colors.white,
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write your code here...',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
            ),
          ),

          // Input Section
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Input (stdin):',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _inputController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Enter input here...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),

          // Output Section
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.black87,
              child: SingleChildScrollView(
                child: Text(
                  _output.isEmpty ? 'Output will appear here...' : _output,
                  style: const TextStyle(
                    fontFamily: 'Courier',
                    color: Colors.greenAccent,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),

          // Run Button
          Container(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isRunning ? null : _runCode,
              icon: _isRunning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isRunning ? 'Running...' : 'Run Code'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
