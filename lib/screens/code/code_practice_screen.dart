import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_colors.dart';

const _langIds = {
  'Python': 71,
  'Java': 62,
  'C++': 54,
  'C': 50,
  'JavaScript': 63,
};

const _hlLang = {
  'Python': 'python',
  'Java': 'java',
  'C++': 'cpp',
  'C': 'c',
  'JavaScript': 'javascript',
};

const _templates = {
  'Python': '# Python\ndef solution():\n    print("Hello, World!")\n\nsolution()',
  'Java':
      'public class Main {\n    public static void main(String[] args) {\n        System.out.println("Hello, World!");\n    }\n}',
  'C++':
      '#include <iostream>\nusing namespace std;\n\nint main() {\n    cout << "Hello, World!" << endl;\n    return 0;\n}',
  'C': '#include <stdio.h>\n\nint main() {\n    printf("Hello, World!\\n");\n    return 0;\n}',
  'JavaScript':
      '// JavaScript\nfunction solution() {\n    console.log("Hello, World!");\n}\n\nsolution();',
};

const _rapidApiKey = 'bf7032d14emsh90fc40dd95168abp18bb71jsn6c16bc00184a';
const _judge0Base = 'https://judge0-ce.p.rapidapi.com';

class CodePracticeScreen extends StatefulWidget {
  final int topicId;
  final String topicTitle;

  const CodePracticeScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  State<CodePracticeScreen> createState() => _CodePracticeScreenState();
}

class _CodePracticeScreenState extends State<CodePracticeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _outputTab;
  final _codeCtrl = TextEditingController();
  final _stdinCtrl = TextEditingController();
  final _codeScroll = ScrollController();
  final _lineScroll = ScrollController();

  String _lang = 'Python';
  String _stdout = '';
  String _stderr = '';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _outputTab = TabController(length: 2, vsync: this);
    _codeCtrl.text = _templates[_lang]!;
    _codeScroll.addListener(() {
      if (_lineScroll.hasClients) {
        _lineScroll.jumpTo(_codeScroll.offset);
      }
    });
  }

  @override
  void dispose() {
    _outputTab.dispose();
    _codeCtrl.dispose();
    _stdinCtrl.dispose();
    _codeScroll.dispose();
    _lineScroll.dispose();
    super.dispose();
  }

  void _changeLang(String lang) => setState(() {
        _lang = lang;
        _codeCtrl.text = _templates[lang]!;
      });

  int get _lineCount =>
      _codeCtrl.text.isEmpty ? 1 : '\n'.allMatches(_codeCtrl.text).length + 1;

  Future<void> _runCode() async {
    if (_running) return;
    FocusScope.of(context).unfocus();
    setState(() { _running = true; _stdout = ''; _stderr = ''; });

    try {
      final submitRes = await http.post(
        Uri.parse('$_judge0Base/submissions?base64_encoded=false&wait=false'),
        headers: {
          'Content-Type': 'application/json',
          'X-RapidAPI-Key': _rapidApiKey,
          'X-RapidAPI-Host': 'judge0-ce.p.rapidapi.com',
        },
        body: jsonEncode({
          'source_code': _codeCtrl.text,
          'language_id': _langIds[_lang] ?? 71,
          'stdin': _stdinCtrl.text,
        }),
      );

      if (submitRes.statusCode != 201) {
        setState(() {
          _stderr = 'Submission failed (${submitRes.statusCode})\n${submitRes.body}';
          _running = false;
        });
        _outputTab.animateTo(1);
        return;
      }

      final token = jsonDecode(submitRes.body)['token'] as String;

      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 800));
        final res = await http.get(
          Uri.parse('$_judge0Base/submissions/$token?base64_encoded=false'),
          headers: {
            'X-RapidAPI-Key': _rapidApiKey,
            'X-RapidAPI-Host': 'judge0-ce.p.rapidapi.com',
          },
        );
        final data = jsonDecode(res.body);
        final statusId = data['status']?['id'] as int? ?? 0;
        if (statusId <= 2) continue;

        final out = data['stdout'] as String? ?? '';
        final err = (data['stderr'] ?? data['compile_output'] ?? '') as String;
        setState(() {
          _stdout = out.isEmpty ? '(no output)' : out;
          _stderr = err;
          _running = false;
        });
        if (err.isNotEmpty) _outputTab.animateTo(1);
        return;
      }
      setState(() { _stderr = 'Timed out.'; _running = false; });
      _outputTab.animateTo(1);
    } catch (e) {
      setState(() { _stderr = 'Error: $e'; _running = false; });
      _outputTab.animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1b26),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _editorArea()),
            _stdinRow(),
            _outputPanel(),
            _runBar(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() => Container(
    padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
    color: const Color(0xFF16213e),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
        ),
        Expanded(
          child: Text(widget.topicTitle,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _lang,
              dropdownColor: const Color(0xFF1e2030),
              style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13),
              icon: const Icon(Icons.expand_more, color: AppColors.primaryBlue, size: 16),
              isDense: true,
              items: _langIds.keys.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
              onChanged: (v) { if (v != null) _changeLang(v); },
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: _codeCtrl.text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)));
            }
          },
          icon: const Icon(Icons.copy_rounded, color: Colors.white38, size: 18),
        ),
      ],
    ),
  );

  // Editor: line numbers + syntax-highlighted overlay + transparent TextField on top
  Widget _editorArea() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Line numbers
      SizedBox(
        width: 44,
        child: ListView.builder(
          controller: _lineScroll,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12),
          itemCount: _lineCount,
          itemBuilder: (_, i) => SizedBox(
            height: 22.4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text('${i + 1}',
                  style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 14,
                    color: Color(0xFF4a4b6a), height: 1.6)),
              ),
            ),
          ),
        ),
      ),
      Container(width: 1, color: const Color(0xFF2a2b3d)),
      // Highlighted code + transparent input stacked
      Expanded(
        child: Stack(
          children: [
            // Syntax highlighted background (scrolls with code)
            SingleChildScrollView(
              controller: _codeScroll,
              padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
              child: HighlightView(
                _codeCtrl.text.isEmpty ? ' ' : _codeCtrl.text,
                language: _hlLang[_lang] ?? 'plaintext',
                theme: atomOneDarkTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
            // Transparent TextField on top for input
            TextField(
              controller: _codeCtrl,
              scrollController: _codeScroll,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.6,
                color: Colors.transparent, // text is invisible — highlight shows through
              ),
              cursorColor: const Color(0xFF89DCEB),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(10, 12, 10, 12),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _stdinRow() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    color: const Color(0xFF1e2030),
    child: Row(
      children: [
        const Text('stdin:', style: TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'monospace')),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _stdinCtrl,
            style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace'),
            decoration: const InputDecoration(
              hintText: 'optional input...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _outputPanel() => Container(
    height: 160,
    decoration: const BoxDecoration(
      color: Color(0xFF13131f),
      border: Border(top: BorderSide(color: Color(0xFF2a2b3d))),
    ),
    child: Column(
      children: [
        Container(
          color: const Color(0xFF1a1b26),
          child: TabBar(
            controller: _outputTab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
              insets: EdgeInsets.symmetric(horizontal: 8),
            ),
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: Colors.white38,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
            tabs: const [Tab(text: 'stdout'), Tab(text: 'stderr')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _outputTab,
            children: [
              _outView(_stdout.isEmpty && !_running ? '// run your code to see output' : _stdout, AppColors.primaryGreen),
              _outView(_stderr.isEmpty ? '// no errors' : _stderr, const Color(0xFFf7768e)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _outView(String text, Color color) => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Text(text,
      style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: color, height: 1.5)),
  );

  Widget _runBar() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    color: const Color(0xFF16213e),
    child: GestureDetector(
      onTap: _running ? null : _runCode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: _running
              ? const LinearGradient(colors: [Color(0xFF2a2b3d), Color(0xFF2a2b3d)])
              : const LinearGradient(colors: [Color(0xFF58CC02), Color(0xFF3FAF00)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _running ? [] : [
            BoxShadow(color: AppColors.primaryGreen.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_running)
              const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
            else
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(_running ? 'Running...' : 'Run Code',
              style: TextStyle(
                color: _running ? Colors.white38 : Colors.white,
                fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    ),
  );
}
