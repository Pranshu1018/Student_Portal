import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:student_portal/core/constants/app_colors.dart';
import 'package:student_portal/providers/auth_provider.dart';
import 'package:student_portal/providers/content_provider.dart';
import 'package:student_portal/screens/subjects/modern_topics_screen.dart';

// ─────────────────────────────────────────────────────────────
// Static subject metadata (icon + color only, no hardcoded progress)
// ─────────────────────────────────────────────────────────────
const _subjectMeta = {
  1: {'shortName': 'DSA',    'icon': Icons.account_tree_rounded, 'color': AppColors.dsaColor},
  2: {'shortName': 'DBMS',   'icon': Icons.storage_rounded,      'color': AppColors.dbmsColor},
  3: {'shortName': 'OS',     'icon': Icons.computer_rounded,     'color': AppColors.osColor},
  4: {'shortName': 'CN',     'icon': Icons.lan_rounded,          'color': AppColors.cnColor},
  5: {'shortName': 'Python', 'icon': Icons.code_rounded,         'color': AppColors.pythonColor},
  6: {'shortName': 'Java',   'icon': Icons.coffee_rounded,       'color': AppColors.javaColor},
};

// ─────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────
class ModernSubjectsScreen extends ConsumerStatefulWidget {
  const ModernSubjectsScreen({super.key});

  @override
  ConsumerState<ModernSubjectsScreen> createState() =>
      _ModernSubjectsScreenState();
}

class _ModernSubjectsScreenState extends ConsumerState<ModernSubjectsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final uid           = ref.watch(authProvider).user?.id ?? '';
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [AppColors.primaryGreen, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header + search ──────────────────────────────
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInDown(
                      child: const Text(
                        'Choose Your Subject',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      child: const Text(
                        'Start learning something new today',
                        style:
                            TextStyle(fontSize: 14, color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInDown(
                      delay: const Duration(milliseconds: 200),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: TextField(
                          onChanged: (v) =>
                              setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: 'Search subjects...',
                            prefixIcon: const Icon(Icons.search,
                                color: AppColors.primaryGreen),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Grid ─────────────────────────────────────────
              Expanded(
                child: subjectsAsync.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryGreen)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (subjects) {
                    final filtered = _searchQuery.isEmpty
                        ? subjects
                        : subjects
                            .where((s) => s.name
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                            .toList();

                    return AnimationLimiter(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(20),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final subject = filtered[index];
                          final meta =
                              _subjectMeta[subject.id] ?? {
                            'shortName': subject.name,
                            'icon': Icons.book_rounded,
                            'color': AppColors.primaryGreen,
                          };

                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 500),
                            columnCount: 2,
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: _SubjectCard(
                                  subjectId:   subject.id,
                                  subjectName: subject.name,
                                  shortName:   meta['shortName'] as String,
                                  icon:        meta['icon']      as IconData,
                                  color:       meta['color']     as Color,
                                  userId:      uid,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SUBJECT CARD — loads its own progress from Firestore
// ─────────────────────────────────────────────────────────────
class _SubjectCard extends ConsumerWidget {
  final int      subjectId;
  final String   subjectName;
  final String   shortName;
  final IconData icon;
  final Color    color;
  final String   userId;

  const _SubjectCard({
    required this.subjectId,
    required this.subjectName,
    required this.shortName,
    required this.icon,
    required this.color,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = userId.isEmpty
        ? const AsyncValue<Map<int, int>>.data({})
        : ref.watch(subjectProgressProvider(
            (userId: userId, subjectId: subjectId)));

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ModernTopicsScreen(
            subjectId:   subjectId,
            subjectName: subjectName,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color:  color.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon circle
            Container(
              width:  70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)]),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 35),
            ),
            const SizedBox(height: 16),

            // Subject short name
            Text(
              shortName,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),

            // Progress bar + label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: progressAsync.when(
                loading: () => Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: 0,
                      backgroundColor: AppColors.backgroundLight,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Loading...',
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600)),
                ]),
                error: (_, __) => const SizedBox.shrink(),
                data: (progressMap) {
                  final totalTopics     = progressMap.length;
                  final completedTopics =
                      progressMap.values.where((p) => p > 0).length;
                  final avgProgress = totalTopics == 0
                      ? 0.0
                      : progressMap.values.fold(0, (a, b) => a + b) /
                          (totalTopics * 100.0);
                  final pct = (avgProgress * 100).round();

                  return Column(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: avgProgress.clamp(0.0, 1.0),
                        backgroundColor: AppColors.backgroundLight,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalTopics == 0
                          ? '0% Complete'
                          : '$pct% ($completedTopics/$totalTopics topics)',
                      style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}