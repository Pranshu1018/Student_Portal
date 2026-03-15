import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/content_provider.dart';
import 'modern_topic_detail_screen.dart';

class ModernTopicsScreen extends ConsumerWidget {
  final int subjectId;
  final String subjectName;

  const ModernTopicsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topicsAsync = ref.watch(topicsProvider(subjectId));

    return Scaffold(
      body: Container(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Choose a topic to learn',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Topics List
              Expanded(
                child: topicsAsync.when(
                  data: (topics) {
                    if (topics.isEmpty) {
                      return Center(
                        child: FadeIn(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.topic_outlined,
                                size: 80,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No topics available',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: topics.length,
                        itemBuilder: (context, index) {
                          final topic = topics[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 500),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _buildTopicCard(context, ref, topic, index),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  error: (error, stack) => Center(
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
                          'Error: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopicCard(BuildContext context, WidgetRef ref, dynamic topic, int index) {
    final colors = [
      AppColors.primaryBlue,
      AppColors.primaryPurple,
      AppColors.primaryOrange,
      AppColors.primaryGreen,
    ];
    final color = colors[index % colors.length];
    final userId = ref.watch(authProvider).user?.id ?? '';
    final progressAsync = ref.watch(topicProgressProvider((userId: userId, topicId: topic.id)));

    return GestureDetector(
      onTap: () {
        final authState = ref.read(authProvider);
        final uid = authState.user?.id;
        if (uid != null) {
          ref.read(firestoreServiceProvider).saveLastVisitedTopic(
            userId: uid,
            topicId: topic.id,
            topicTitle: topic.title,
            subjectName: subjectName,
            subjectId: subjectId,
          );
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ModernTopicDetailScreen(
              topicId: topic.id,
              topicTitle: topic.title,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color.withOpacity(0.8), color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.book_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  progressAsync.when(
                    loading: () => const SizedBox(height: 6, width: 80, child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (score) => score > 0
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: score / 100,
                                backgroundColor: AppColors.backgroundLight,
                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                minHeight: 5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('Best score: $score%', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          ])
                        : Text('Not attempted yet', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            progressAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (score) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: score > 0 ? color.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  score >= 80 ? Icons.check_circle : Icons.arrow_forward_ios,
                  color: score >= 80 ? color : (score > 0 ? color : Colors.grey),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
