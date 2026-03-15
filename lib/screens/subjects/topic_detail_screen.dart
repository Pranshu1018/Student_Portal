import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/content_provider.dart';
import '../../models/topic_model.dart';
import '../quiz/quiz_screen.dart';
import '../code/code_practice_screen.dart';

class TopicDetailScreen extends ConsumerStatefulWidget {
  final int topicId;

  const TopicDetailScreen({super.key, required this.topicId});

  @override
  ConsumerState<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends ConsumerState<TopicDetailScreen>
    with SingleTickerProviderStateMixin {
  YoutubePlayerController? _youtubeController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _youtubeController?.close();
    _tabController.dispose();
    super.dispose();
  }

  void _initializeYoutubePlayer(String videoUrl) {
    final videoId = YoutubePlayerController.convertUrlToId(videoUrl);
    if (videoId != null) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
          showControls: true,
          loop: false,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topicAsync = ref.watch(topicDetailProvider(widget.topicId));

    return Scaffold(
      body: topicAsync.when(
        data: (topic) {
          // Initialize YouTube player if needed
          if (topic.videoUrl != null && 
              topic.videoUrl!.isNotEmpty && 
              _youtubeController == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _initializeYoutubePlayer(topic.videoUrl!);
              });
            });
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    topic.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.article,
                        size: 80,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.play_circle_outline),
                      text: 'Video',
                    ),
                    Tab(
                      icon: Icon(Icons.article_outlined),
                      text: 'Notes',
                    ),
                  ],
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Video Tab
                    _buildVideoTab(topic),
                    // Notes Tab
                    _buildNotesTab(topic),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stack) => Scaffold(
          appBar: AppBar(
            title: const Text('Error'),
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.refresh(topicDetailProvider(widget.topicId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTab(Topic topic) {
    if (topic.videoUrl == null || topic.videoUrl!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No video available for this topic',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Show loading if controller not ready
    if (_youtubeController == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading video...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Video Player
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: YoutubePlayer(
                controller: _youtubeController!,
                aspectRatio: 16 / 9,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          topicId: topic.id,
                          topicTitle: topic.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.quiz),
                  label: const Text('Take Quiz'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CodePracticeScreen(
                          topicId: topic.id,
                          topicTitle: topic.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.code),
                  label: const Text('Practice'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab(Topic topic) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Content Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                  ? topic.content
                  : 'No notes available for this topic yet.\n\nContent will be added soon through web scraping from educational platforms like GeeksforGeeks and TutorialsPoint.',
              style: const TextStyle(
                fontSize: 16,
                height: 1.8,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.info.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Content is sourced from educational platforms and formatted for better learning experience.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          topicId: topic.id,
                          topicTitle: topic.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.quiz),
                  label: const Text('Take Quiz'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CodePracticeScreen(
                          topicId: topic.id,
                          topicTitle: topic.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.code),
                  label: const Text('Practice'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.primaryBlue,
                    side: const BorderSide(color: AppColors.primaryBlue),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
