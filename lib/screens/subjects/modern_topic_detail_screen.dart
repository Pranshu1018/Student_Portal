import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/content_provider.dart';
import '../../services/firebase_firestore_service.dart';
import '../quiz/modern_quiz_screen.dart';
import '../code/code_practice_screen.dart';

class ModernTopicDetailScreen extends ConsumerStatefulWidget {
  final int topicId;
  final String topicTitle;

  const ModernTopicDetailScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  ConsumerState<ModernTopicDetailScreen> createState() =>
      _ModernTopicDetailScreenState();
}

class _ModernTopicDetailScreenState
    extends ConsumerState<ModernTopicDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _fetchingNotes = false;
  String? _fetchedContent;
  String _fetchStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Auto-fetch when Notes tab is selected
      if (_tabController.index == 1 && !_fetchingNotes && _fetchedContent == null) {
        _autoFetchNotes();
      }
    });
  }

  Future<void> _autoFetchNotes({String existingContent = ''}) async {
    if (existingContent.length > 300) return; // already has rich content
    if (_fetchingNotes) return;
    setState(() { _fetchingNotes = true; _fetchStatus = 'Fetching notes from GeeksforGeeks...'; });
    try {
      final db = FirebaseFirestoreService();
      final content = await db.autoFetchNotes(
        topicId: widget.topicId,
        topicTitle: widget.topicTitle,
      );
      if (mounted) {
        setState(() {
          _fetchingNotes = false;
          if (content != null && content.isNotEmpty) {
            _fetchedContent = content;
            _fetchStatus = '';
          } else {
            _fetchStatus = 'Could not fetch notes. Backend may be offline.';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() { _fetchingNotes = false; _fetchStatus = 'Error: $e'; });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicAsync = ref.watch(topicDetailProvider(widget.topicId));

    return Scaffold(
      body: topicAsync.when(
        data: (topic) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryBlue.withOpacity(0.1),
                  AppColors.primaryPurple.withOpacity(0.1),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Custom App Bar
                  FadeInDown(
                    duration: const Duration(milliseconds: 500),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              widget.topicTitle,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tab Bar
                  FadeInDown(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: AppColors.blueGradient,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        tabs: const [
                          Tab(text: 'Video'),
                          Tab(text: 'Notes'),
                        ],
                      ),
                    ),
                  ),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildVideoTab(topic),
                        _buildNotesTab(topic),
                      ],
                    ),
                  ),

                  // Action Buttons
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModernQuizScreen(
                                      topicId: widget.topicId,
                                      topicTitle: widget.topicTitle,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.quiz_rounded),
                              label: const Text('Take Quiz'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CodePracticeScreen(
                                      topicId: widget.topicId,
                                      topicTitle: widget.topicTitle,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.code_rounded),
                              label: const Text('Practice'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue.withOpacity(0.1),
                AppColors.primaryPurple.withOpacity(0.1),
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
            ),
          ),
        ),
        error: (error, stack) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryBlue.withOpacity(0.1),
                AppColors.primaryPurple.withOpacity(0.1),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading topic',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTab(dynamic topic) {
    return FadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Section
            if (topic.videoUrl != null && topic.videoUrl!.isNotEmpty)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 64,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Video Player',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Videos work on real devices\nNot supported in emulator',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No video available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // About Section
            const Text(
              'About this topic',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                topic.content.isNotEmpty
                    ? (topic.content.length > 300
                        ? topic.content.substring(0, 300) + '...\n\nSee Notes tab for full content'
                        : topic.content)
                    : 'No description available',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesTab(dynamic topic) {
    // Use fetched content if available, otherwise fall back to Firestore content
    final content = (_fetchedContent != null && _fetchedContent!.isNotEmpty)
        ? _fetchedContent!
        : topic.content as String;

    // Trigger auto-fetch if content is thin
    if (!_fetchingNotes && _fetchedContent == null && content.length < 300) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoFetchNotes(existingContent: content));
    }

    return FadeIn(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.blueGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notes_rounded, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Study Notes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(widget.topicTitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                      ],
                    ),
                  ),
                  // Refresh button
                  IconButton(
                    icon: _fetchingNotes
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _fetchingNotes ? null : () {
                      setState(() { _fetchedContent = null; });
                      _autoFetchNotes();
                    },
                    tooltip: 'Refresh from GeeksforGeeks',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Loading / status indicator
            if (_fetchingNotes)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_fetchStatus, style: const TextStyle(fontSize: 14, color: AppColors.primaryBlue))),
                  ],
                ),
              )
            else if (_fetchStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(_fetchStatus, style: TextStyle(fontSize: 13, color: Colors.orange.shade800)),
              ),

            if (_fetchingNotes) const SizedBox(height: 12),

            // Content blocks
            if (content.isNotEmpty && !_fetchingNotes)
              ..._parseContent(content)
            else if (!_fetchingNotes && content.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No notes available.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16))),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _parseContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final buffer = StringBuffer();
    bool inCodeBlock = false;
    String codeBuffer = '';

    void flushBuffer() {
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        widgets.add(_textBlock(text));
        buffer.clear();
      }
    }

    for (final line in lines) {
      if (line.startsWith('```')) {
        if (!inCodeBlock) {
          flushBuffer();
          inCodeBlock = true;
          codeBuffer = '';
        } else {
          inCodeBlock = false;
          widgets.add(_codeBlock(codeBuffer.trim()));
          codeBuffer = '';
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer += '$line\n';
        continue;
      }

      if (line.startsWith('## ') || line.startsWith('# ')) {
        flushBuffer();
        widgets.add(_sectionHeader(line.replaceAll(RegExp(r'^#+\s*'), '')));
      } else if (line.startsWith('### ')) {
        flushBuffer();
        widgets.add(_subHeader(line.replaceAll('### ', '')));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flushBuffer();
        widgets.add(_bulletPoint(line.substring(2)));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        flushBuffer();
        widgets.add(_numberedPoint(line));
      } else if (line.trim().isEmpty) {
        flushBuffer();
        widgets.add(const SizedBox(height: 8));
      } else {
        buffer.writeln(line);
      }
    }
    flushBuffer();
    return widgets;
  }

  Widget _sectionHeader(String text) => Container(
    margin: const EdgeInsets.only(top: 24, bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.primaryBlue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: AppColors.primaryBlue, width: 5)),
    ),
    child: Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
  );

  Widget _subHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
  );

  Widget _textBlock(String text) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Text(text, style: const TextStyle(fontSize: 17, color: AppColors.textSecondary, height: 1.8)),
  );

  Widget _bulletPoint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 9),
          width: 8, height: 8,
          decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 17, color: AppColors.textSecondary, height: 1.7))),
      ],
    ),
  );

  Widget _numberedPoint(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
    child: Text(text, style: const TextStyle(fontSize: 17, color: AppColors.textSecondary, height: 1.7)),
  );

  Widget _codeBlock(String code) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E2E),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFF313244), width: 1),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 15,
          color: Color(0xFF89DCEB),
          height: 1.7,
        ),
      ),
    ),
  );
}
