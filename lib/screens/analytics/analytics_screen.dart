import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_firestore_service.dart';

// ── Leaderboard provider ──────────────────────────────────────
final _leaderboardProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .orderBy('total_xp', descending: true)
      .limit(50)
      .get();
  return snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _db = FirebaseFirestoreService();
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final userId = ref.read(authProvider).user?.id;
    if (userId == null) { setState(() => _loading = false); return; }
    final data = await _db.getUserDashboard(userId);
    final results = await _db.getUserQuizResults(userId);
    final enriched = <Map<String, dynamic>>[];
    for (final r in results.take(10)) {
      final topicId = (r['topic_id'] as num?)?.toInt() ?? 0;
      String topicTitle = 'Topic $topicId';
      if (topicId > 0) {
        final topic = await _db.getTopicDetail(topicId);
        if (topic != null) topicTitle = topic.title;
      }
      enriched.add({...r, 'topic_title': topicTitle});
    }
    if (mounted) setState(() { _data = {...data, 'enriched_activity': enriched}; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [_buildProgressTab(), _buildLeaderboardTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF9D4EDD), Color(0xFF1CB0F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Progress & Leaderboard', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Track your learning journey', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            GestureDetector(
              onTap: () { _load(); ref.invalidate(_leaderboardProvider); },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.primaryPurple, width: 3),
          insets: EdgeInsets.symmetric(horizontal: 20),
        ),
        labelColor: AppColors.primaryPurple,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(icon: Icon(Icons.insights_rounded, size: 18), text: 'Progress'),
          Tab(icon: Icon(Icons.leaderboard_rounded, size: 18), text: 'Leaderboard'),
        ],
      ),
    );
  }

  // ── PROGRESS TAB ─────────────────────────────────────────────
  Widget _buildProgressTab() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple));
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(),
            const SizedBox(height: 16),
            _buildAccuracyCard(),
            const SizedBox(height: 16),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final total = _data['total_quizzes'] ?? 0;
    final avg = (_data['average_score'] ?? 0.0) as double;
    final accuracy = (_data['overall_accuracy'] ?? 0.0) as double;
    return FadeInUp(
      child: Row(
        children: [
          Expanded(child: _statCard('Quizzes', total.toString(), Icons.quiz_rounded, AppColors.primaryBlue)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('Avg Score', '${avg.toStringAsFixed(0)}%', Icons.star_rounded, AppColors.primaryOrange)),
          const SizedBox(width: 12),
          Expanded(child: _statCard('Accuracy', '${accuracy.toStringAsFixed(0)}%', Icons.check_circle_rounded, AppColors.primaryGreen)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildAccuracyCard() {
    final accuracy = (_data['overall_accuracy'] ?? 0.0) as double;
    final color = accuracy >= 80 ? AppColors.primaryGreen : accuracy >= 60 ? AppColors.primaryOrange : AppColors.error;
    return FadeInUp(
      delay: const Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 50,
              lineWidth: 8,
              percent: (accuracy / 100).clamp(0.0, 1.0),
              center: Text('${accuracy.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              progressColor: color,
              backgroundColor: color.withOpacity(0.15),
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Overall Accuracy', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Text(
                    accuracy >= 80 ? 'Excellent! Keep it up.' : accuracy >= 60 ? 'Good progress. Keep practicing.' : 'Keep going, you\'ll improve!',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final activity = (_data['enriched_activity'] as List?) ?? [];
    return FadeInUp(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Quizzes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          if (activity.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.quiz_outlined, size: 48, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text('No quizzes taken yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                  ],
                ),
              ),
            )
          else
            ...activity.map((r) => _activityCard(r)),
        ],
      ),
    );
  }

  Widget _activityCard(Map<String, dynamic> r) {
    final pct = (r['percentage'] ?? 0) as int;
    final title = r['topic_title'] ?? 'Quiz';
    final score = r['score'] ?? 0;
    final total = r['total_questions'] ?? 0;
    final ts = r['timestamp'];
    String timeAgo = '';
    if (ts != null) {
      try {
        final dt = ts.toDate() as DateTime;
        final diff = DateTime.now().difference(dt);
        if (diff.inDays > 0) timeAgo = '${diff.inDays}d ago';
        else if (diff.inHours > 0) timeAgo = '${diff.inHours}h ago';
        else timeAgo = '${diff.inMinutes}m ago';
      } catch (_) {}
    }
    final color = pct >= 80 ? AppColors.primaryGreen : pct >= 60 ? AppColors.primaryOrange : AppColors.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(Icons.quiz_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$score/$total correct  •  $timeAgo', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('$pct%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── LEADERBOARD TAB ──────────────────────────────────────────
  Widget _buildLeaderboardTab() {
    final leaderAsync = ref.watch(_leaderboardProvider);
    final currentUid = ref.watch(authProvider).user?.id ?? '';
    return leaderAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primaryPurple)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (users) => _buildLeaderList(users, currentUid),
    );
  }

  Widget _buildLeaderList(List<Map<String, dynamic>> users, String currentUid) {
    if (users.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.leaderboard_outlined, size: 72, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text('No data yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            SizedBox(height: 6),
            Text('Take quizzes to earn XP and appear here', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    // Find current user rank
    final myRank = users.indexWhere((u) => u['id'] == currentUid);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          // My rank banner (if not in top 3)
          if (myRank > 2)
            FadeInDown(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF9D4EDD), Color(0xFF1CB0F6)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Text('Your rank: #${myRank + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    const Spacer(),
                    Text('${users[myRank]['total_xp'] ?? 0} XP', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),

          // Podium (top 3)
          if (users.length >= 3) ...[
            FadeInDown(
              delay: const Duration(milliseconds: 100),
              child: _buildPodium(users.take(3).toList(), currentUid),
            ),
            const SizedBox(height: 16),
          ],

          // Rank 4+
          ...users.skip(3).toList().asMap().entries.map((e) {
            final rank = e.key + 4;
            final user = e.value;
            final isMe = user['id'] == currentUid;
            return FadeInUp(
              delay: Duration(milliseconds: (rank - 3) * 50),
              child: _leaderTile(rank, user, isMe),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> top3, String currentUid) {
    // Order: 2nd, 1st, 3rd for visual podium
    final order = [top3[1], top3[0], top3[2]];
    final ranks = [2, 1, 3];
    final heights = [90.0, 110.0, 75.0];
    final colors = [AppColors.silverStar, AppColors.goldStar, AppColors.bronzeStar];
    final medals = ['🥈', '🥇', '🥉'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          const Text('Top Learners', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (i) {
              final user = order[i];
              final isMe = user['id'] == currentUid;
              final name = (user['name'] as String? ?? 'User').split(' ').first;
              final xp = user['total_xp'] ?? 0;
              return Expanded(
                child: Column(
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: colors[i].withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: colors[i], width: isMe ? 3 : 2),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(name, style: TextStyle(fontSize: 12, fontWeight: isMe ? FontWeight.bold : FontWeight.w500, color: isMe ? AppColors.primaryPurple : AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    Text('$xp XP', style: TextStyle(fontSize: 11, color: colors[i], fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      height: heights[i],
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colors[i].withOpacity(0.6), colors[i].withOpacity(0.3)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      ),
                      child: Center(
                        child: Text('#${ranks[i]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _leaderTile(int rank, Map<String, dynamic> user, bool isMe) {
    final name = user['name'] as String? ?? 'User';
    final xp = user['total_xp'] ?? 0;
    final quizzes = user['quizzes_taken'] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isMe ? AppColors.primaryPurple.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isMe ? Border.all(color: AppColors.primaryPurple.withOpacity(0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('#$rank', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isMe ? AppColors.primaryPurple : AppColors.textSecondary)),
          ),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: (isMe ? AppColors.primaryPurple : AppColors.primaryBlue).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isMe ? AppColors.primaryPurple : AppColors.primaryBlue),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '$name (You)' : name,
                  style: TextStyle(fontSize: 14, fontWeight: isMe ? FontWeight.bold : FontWeight.w500, color: isMe ? AppColors.primaryPurple : AppColors.textPrimary),
                ),
                Text('$quizzes quizzes taken', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: (isMe ? AppColors.primaryPurple : AppColors.primaryBlue).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$xp XP', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMe ? AppColors.primaryPurple : AppColors.primaryBlue)),
          ),
        ],
      ),
    );
  }
}
