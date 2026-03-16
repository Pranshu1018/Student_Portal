import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

  YoutubePlayerController? _ytController;
  bool _ytReady = false;
  bool _ytError = false;
  String? _videoId;

  bool _fetchingNotes = false;
  bool _notesFetchTriggered = false;
  String? _fetchedContent;
  String _fetchStatus = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChange);
    _loadVideoOnce();
  }

  void _onTabChange() {
    if (_tabController.index == 1 && !_notesFetchTriggered) {
      _notesFetchTriggered = true;
      _autoFetchNotes();
    }
  }

  Future<void> _loadVideoOnce() async {
    try {
      final db = FirebaseFirestoreService();
      final topic = await db.getTopicDetail(widget.topicId);
      if (!mounted) return;
      final url = topic?.videoUrl as String?;
      final vid = url != null ? YoutubePlayer.convertUrlToId(url.trim()) : null;
      if (vid != null && vid.isNotEmpty) {
        _videoId = vid;
        _ytController = YoutubePlayerController(
          initialVideoId: vid,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
            enableCaption: false,
            hideControls: false,
            controlsVisibleAtStart: true,
            disableDragSeek: false,
            loop: false,
            isLive: false,
            useHybridComposition: true,
          ),
        );
        // Listener: play as soon as the player is ready/cued
        _ytController!.addListener(_ytListener);
        setState(() => _ytReady = true);
      } else {
        setState(() => _ytError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _ytError = true);
    }
  }

  bool _playTriggered = false;
  void _ytListener() {
    if (_ytController == null) return;
    final state = _ytController!.value.playerState;
    if (!_playTriggered &&
        (state == PlayerState.cued || state == PlayerState.buffering)) {
      _playTriggered = true;
      _ytController!.play();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    _ytController?.removeListener(_ytListener);
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _autoFetchNotes({String existingContent = ''}) async {
    if (existingContent.length > 300 || _fetchingNotes) return;
    setState(() { _fetchingNotes = true; _fetchStatus = 'Fetching notes...'; });
    try {
      final content = await FirebaseFirestoreService()
          .autoFetchNotes(topicId: widget.topicId, topicTitle: widget.topicTitle);
      if (mounted) {
        setState(() {
          _fetchingNotes = false;
          _fetchedContent = (content != null && content.isNotEmpty) ? content : null;
          _fetchStatus = content != null && content.isNotEmpty
              ? ''
              : 'Could not fetch notes. Backend may be offline.';
        });
      }
    } catch (e) {
      if (mounted) setState(() { _fetchingNotes = false; _fetchStatus = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicAsync = ref.watch(topicDetailProvider(widget.topicId));

    Widget innerContent = topicAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (topic) => Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVideoTab(topic),
                _buildNotesTab(topic),
              ],
            ),
          ),
          _buildActionBar(),
        ],
      ),
    );

    if (_ytReady && _ytController != null) {
      return YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: _ytController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: AppColors.primaryBlue,
          progressColors: const ProgressBarColors(
            playedColor: AppColors.primaryBlue,
            handleColor: AppColors.primaryPurple,
          ),
          onReady: () {
            _playTriggered = true;
            _ytController!.play();
          },
        ),
        builder: (ctx, player) => Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                topicAsync.when(
                  loading: () => const Expanded(
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
                  ),
                  error: (e, _) => Expanded(child: Center(child: Text('Error: $e'))),
                  data: (topic) => Expanded(
                    child: Column(
                      children: [
                        _buildTabBar(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildVideoTab(topic, player: player),
                              _buildNotesTab(topic),
                            ],
                          ),
                        ),
                        _buildActionBar(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: innerContent),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(4, 10, 16, 10),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1CB0F6), Color(0xFF9D4EDD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
        ),
        Expanded(
          child: Text(widget.topicTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabController,
      indicator: const UnderlineTabIndicator(
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 3),
        insets: EdgeInsets.symmetric(horizontal: 20),
      ),
      labelColor: AppColors.primaryBlue,
      unselectedLabelColor: AppColors.textSecondary,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      tabs: const [
        Tab(icon: Icon(Icons.play_circle_outline, size: 20), text: 'Video'),
        Tab(icon: Icon(Icons.menu_book_rounded, size: 20), text: 'Notes'),
      ],
    ),
  );

  Widget _buildVideoTab(dynamic topic, {Widget? player}) {
    final videoUrl = topic.videoUrl as String?;
    final vid = videoUrl != null ? YoutubePlayer.convertUrlToId(videoUrl.trim()) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video area
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: player != null
                ? player
                : vid != null
                    ? _tapToOpenWidget(vid)
                    : _noVideoWidget(),
          ),
          const SizedBox(height: 20),
          // About card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(gradient: AppColors.blueGradient, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text('About this Topic',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                ]),
                const SizedBox(height: 12),
                Text(() {
                  final c = topic.content as String? ?? '';
                  if (c.isEmpty) return 'Open the Notes tab to load full content.';
                  if (c.length > 300) return '${c.substring(0, 300)}...\n\nSee Notes tab for full content.';
                  return c;
                }(), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tapToOpenWidget(String vid) => GestureDetector(
    onTap: () => launchUrl(Uri.parse('https://www.youtube.com/watch?v=$vid'),
        mode: LaunchMode.externalApplication),
    child: Container(
      height: 210,
      color: Colors.black,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_circle_fill, size: 64, color: Colors.redAccent),
          SizedBox(height: 10),
          Text('Tap to watch on YouTube', style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    ),
  );

  Widget _noVideoWidget() => Container(
    height: 210,
    color: const Color(0xFF1a1a2e),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.video_library_outlined, size: 56, color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 10),
        Text('No video available', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
      ],
    ),
  );

  Widget _buildNotesTab(dynamic topic) {
    final content = (_fetchedContent?.isNotEmpty == true)
        ? _fetchedContent!
        : (topic.content as String? ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1CB0F6), Color(0xFF9D4EDD)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text('Study Notes — ${widget.topicTitle}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: _fetchingNotes ? null : () {
                  setState(() { _fetchedContent = null; _notesFetchTriggered = false; });
                  _notesFetchTriggered = true;
                  _autoFetchNotes();
                },
                child: _fetchingNotes
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          if (_fetchingNotes)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
                const SizedBox(width: 10),
                Text(_fetchStatus, style: const TextStyle(fontSize: 13, color: AppColors.primaryBlue)),
              ]),
            )
          else if (_fetchStatus.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_fetchStatus,
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade800))),
              ]),
            ),
          const SizedBox(height: 6),
          if (content.isNotEmpty && !_fetchingNotes)
            ..._parseContent(content)
          else if (!_fetchingNotes && content.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No notes available.',
                style: TextStyle(color: AppColors.textSecondary))),
            ),
        ],
      ),
    );
  }

  Widget _buildActionBar() => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -3))],
    ),
    child: Row(children: [
      Expanded(child: _actionBtn(Icons.quiz_rounded, 'Take Quiz',
        const LinearGradient(colors: [Color(0xFF58CC02), Color(0xFF3FAF00)]),
        () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ModernQuizScreen(topicId: widget.topicId, topicTitle: widget.topicTitle))))),
      const SizedBox(width: 12),
      Expanded(child: _actionBtn(Icons.code_rounded, 'Practice',
        const LinearGradient(colors: [Color(0xFFFF9600), Color(0xFFFF7A00)]),
        () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => CodePracticeScreen(topicId: widget.topicId, topicTitle: widget.topicTitle))))),
    ]),
  );

  Widget _actionBtn(IconData icon, String label, Gradient gradient, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ),
    );

  List<Widget> _parseContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    final buf = StringBuffer();
    bool inCode = false;
    String codeBuf = '';

    void flush() {
      final t = buf.toString().trim();
      if (t.isNotEmpty) { widgets.add(_textBlock(t)); buf.clear(); }
    }

    for (final line in lines) {
      if (line.startsWith('```')) {
        if (!inCode) { flush(); inCode = true; codeBuf = ''; }
        else { inCode = false; widgets.add(_codeBlock(codeBuf.trim())); codeBuf = ''; }
        continue;
      }
      if (inCode) { codeBuf += '$line\n'; continue; }
      if (line.startsWith('# ') || line.startsWith('## ')) {
        flush(); widgets.add(_sectionHeader(line.replaceAll(RegExp(r'^#+\s*'), '')));
      } else if (line.startsWith('### ')) {
        flush(); widgets.add(_subHeader(line.replaceAll('### ', '')));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flush(); widgets.add(_bullet(line.substring(2)));
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        flush(); widgets.add(_numbered(line));
      } else if (line.trim().isEmpty) {
        flush(); widgets.add(const SizedBox(height: 6));
      } else {
        buf.writeln(line);
      }
    }
    flush();
    return widgets;
  }

  Widget _sectionHeader(String t) => Container(
    margin: const EdgeInsets.only(top: 16, bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [
        AppColors.primaryBlue.withOpacity(0.1),
        AppColors.primaryPurple.withOpacity(0.06),
      ]),
      borderRadius: BorderRadius.circular(10),
      border: const Border(left: BorderSide(color: AppColors.primaryBlue, width: 4)),
    ),
    child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primaryBlue)),
  );

  Widget _subHeader(String t) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
  );

  Widget _textBlock(String t) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Text(t, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.8)),
  );

  Widget _bullet(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(top: 7),
        width: 6, height: 6,
        decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
      ),
      const SizedBox(width: 9),
      Expanded(child: Text(t, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7))),
    ]),
  );

  Widget _numbered(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Text(t, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7)),
  );

  Widget _codeBlock(String code) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1E1E2E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF313244)),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Text(code,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Color(0xFF89DCEB), height: 1.6)),
    ),
  );
}
