import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:student_portal/core/constants/app_colors.dart';
import 'package:student_portal/providers/auth_provider.dart';
import 'package:student_portal/providers/content_provider.dart';
import 'package:student_portal/screens/subjects/modern_subjects_screen.dart';
import 'package:student_portal/screens/subjects/modern_topic_detail_screen.dart';
import 'package:student_portal/screens/analytics/analytics_screen.dart';
import 'package:student_portal/screens/code/code_practice_screen.dart';

class ModernHomeScreen extends ConsumerStatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  ConsumerState<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends ConsumerState<ModernHomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const _HomeTab(),
      const ModernSubjectsScreen(),
      const AnalyticsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (i) => setState(() => _selectedIndex = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primaryGreen,
          unselectedItemColor: AppColors.textSecondary,
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.school_rounded), label: 'Learn'),
            BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded), label: 'Progress'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HOME TAB
// ─────────────────────────────────────────────────────────────
class _HomeTab extends ConsumerStatefulWidget {
  const _HomeTab();

  @override
  ConsumerState<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<_HomeTab> {
  static const int _dailyGoalXp = 20;

  bool _loading = true;
  int _xp = 0;
  int _streak = 0;
  int _quizzesTaken = 0;
  int _todayXp = 0;
  Map<String, dynamic>? _lastTopic;
  int _topicProgress = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    final uid = ref.read(authProvider).user?.id;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    final svc = ref.read(firestoreServiceProvider);

    try {
      final results = await Future.wait([
        svc.getUserStats(uid),
        svc.getLastVisitedTopic(uid),
        svc.getTodayXp(uid),
      ]);

      final stats     = results[0] as Map<String, dynamic>;
      final lastTopic = results[1] as Map<String, dynamic>?;
      final todayXp   = results[2] as int;

      int topicProgress = 0;
      if (lastTopic != null) {
        final topicId = (lastTopic['topic_id'] as num?)?.toInt() ?? 0;
        if (topicId > 0) {
          topicProgress = await svc.getTopicProgress(uid, topicId);
        }
      }

      if (mounted) {
        setState(() {
          _xp            = (stats['total_xp']     as num?)?.toInt() ?? 0;
          _streak        = (stats['streak_days']   as num?)?.toInt() ?? 0;
          _quizzesTaken  = (stats['quizzes_taken'] as num?)?.toInt() ?? 0;
          _todayXp       = todayXp;
          _lastTopic     = lastTopic;
          _topicProgress = topicProgress;
          _loading       = false;
        });
      }
    } catch (e) {
      debugPrint('Home load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user        = ref.watch(authProvider).user;
    final goalPercent = (_todayXp / _dailyGoalXp).clamp(0.0, 1.0);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0xFF58CC02), Colors.white],
        ),
      ),
      child: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white))
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, user),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildContinueLearning(context),
                      const SizedBox(height: 24),
                      _buildQuickActions(context),
                      const SizedBox(height: 24),
                      _buildDailyGoal(goalPercent),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, dynamic user) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInDown(
                  child: Text(
                    'Hello, ${user?.name ?? "Student"}!',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: const Text('Ready to learn today?',
                      style:
                          TextStyle(fontSize: 14, color: Colors.white70)),
                ),
              ],
            ),
          ),
          FadeInDown(
            delay: const Duration(milliseconds: 200),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: AppColors.streakFire, size: 20),
                  const SizedBox(width: 4),
                  Text('$_streak',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _logout,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: Text(
                    (user?.name?.isNotEmpty == true)
                        ? (user!.name as String)
                            .substring(0, 1)
                            .toUpperCase()
                        : 'S',
                    style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeInUp(
        delay: const Duration(milliseconds: 300),
        child: Row(children: [
          Expanded(
              child: _statCard(Icons.emoji_events_rounded, '$_xp', 'XP',
                  AppColors.goldStar)),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(Icons.check_circle_rounded,
                  '$_quizzesTaken', 'Quizzes', AppColors.success)),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(Icons.today_rounded, '${_todayXp}xp',
                  'Today', AppColors.primaryBlue)),
        ]),
      ),
    );
  }

  Widget _statCard(
      IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _buildContinueLearning(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FadeInLeft(
          delay: const Duration(milliseconds: 400),
          child: const Text('Continue Learning',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 16),
        FadeInUp(
          delay: const Duration(milliseconds: 500),
          child:
              _lastTopic == null ? _noTopicCard() : _resumeCard(context),
        ),
      ]),
    );
  }

  Widget _noTopicCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: const Row(children: [
        Icon(Icons.school_outlined,
            size: 40, color: AppColors.textSecondary),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            'No topic visited yet.\nGo to Learn to get started!',
            style:
                TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ),
      ]),
    );
  }

  Widget _resumeCard(BuildContext context) {
    final title   = _lastTopic!['topic_title']  as String? ?? 'Unknown Topic';
    final subject = _lastTopic!['subject_name'] as String? ?? '';
    final topicId = (_lastTopic!['topic_id']    as num?)?.toInt() ?? 0;
    final progress = (_topicProgress / 100.0).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        if (topicId > 0) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ModernTopicDetailScreen(
                topicId: topicId, topicTitle: title),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.blueGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject.isNotEmpty)
                  Text(subject,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8))),
                const SizedBox(height: 2),
                Text(title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  _topicProgress > 0
                      ? '$_topicProgress% Complete'
                      : 'Not started yet',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 32),
          ),
        ]),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FadeInLeft(
          delay: const Duration(milliseconds: 600),
          child: const Text('Quick Actions',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: FadeInLeft(
              delay: const Duration(milliseconds: 700),
              child: _actionCard(
                context,
                Icons.quiz_rounded,
                'Take Quiz',
                AppColors.purpleGradient,
                () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ModernSubjectsScreen(),
                )),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeInRight(
              delay: const Duration(milliseconds: 700),
              child: _actionCard(
                context,
                Icons.code_rounded,
                'Practice Code',
                AppColors.orangeGradient,
                () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CodePracticeScreen(
                      topicId: 1, topicTitle: 'Practice Coding'),
                )),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String label,
      Gradient gradient, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
        ]),
      ),
    );
  }

  Widget _buildDailyGoal(double goalPercent) {
    final pct = (goalPercent * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FadeInUp(
        delay: const Duration(milliseconds: 800),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            CircularPercentIndicator(
              radius: 40,
              lineWidth: 8,
              percent: goalPercent,
              center: Text('$pct%',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen)),
              progressColor: AppColors.primaryGreen,
              backgroundColor: AppColors.backgroundLight,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Daily Goal',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text('$_todayXp of $_dailyGoalXp XP earned today',
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(
                    goalPercent >= 1.0
                        ? 'Goal reached! 🎉'
                        : 'Keep it up! 💪',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}