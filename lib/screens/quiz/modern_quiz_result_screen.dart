import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:confetti/confetti.dart';
import '../../core/constants/app_colors.dart';

class ModernQuizResultScreen extends StatefulWidget {
  final double score;
  final int correctCount;
  final int wrongCount;
  final List<String> weakSubtopics;
  final String topicTitle;

  const ModernQuizResultScreen({
    super.key,
    required this.score,    required this.correctCount,
    required this.wrongCount,
    required this.weakSubtopics,
    required this.topicTitle,
  });

  @override
  State<ModernQuizResultScreen> createState() => _ModernQuizResultScreenState();
}

class _ModernQuizResultScreenState extends State<ModernQuizResultScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    
    // Show confetti if score is good
    if (widget.score >= 70) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _confettiController.play();
      });
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _getScoreColor() {
    if (widget.score >= 80) return AppColors.success;
    if (widget.score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String _getScoreMessage() {
    if (widget.score >= 90) return 'Outstanding! 🌟';
    if (widget.score >= 80) return 'Excellent Work! 🎉';
    if (widget.score >= 70) return 'Great Job! 👏';
    if (widget.score >= 60) return 'Good Effort! 💪';
    return 'Keep Practicing! 📚';
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = widget.correctCount + widget.wrongCount;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _getScoreColor(),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // Title
                    FadeInDown(
                      child: const Text(
                        'Quiz Complete!',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeInDown(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        widget.topicTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Score Circle
                    ZoomIn(
                      delay: const Duration(milliseconds: 200),
                      child: CircularPercentIndicator(
                        radius: 100,
                        lineWidth: 15,
                        percent: widget.score / 100,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${widget.score.toInt()}%',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(),
                              ),
                            ),
                            Text(
                              _getScoreMessage(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        progressColor: _getScoreColor(),
                        backgroundColor: AppColors.backgroundLight,
                        circularStrokeCap: CircularStrokeCap.round,
                        animation: true,
                        animationDuration: 1500,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Stats Cards
                    FadeInUp(
                      delay: const Duration(milliseconds: 400),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.check_circle_rounded,
                              value: widget.correctCount.toString(),
                              label: 'Correct',
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.cancel_rounded,
                              value: widget.wrongCount.toString(),
                              label: 'Wrong',
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.quiz_rounded,
                              value: totalQuestions.toString(),
                              label: 'Total',
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Weak Subtopics
                    if (widget.weakSubtopics.isNotEmpty)
                      FadeInUp(
                        delay: const Duration(milliseconds: 600),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: AppColors.warning,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Areas to Improve',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...widget.weakSubtopics.map((subtopic) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.warning,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          subtopic,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    FadeInUp(
                      delay: const Duration(milliseconds: 800),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Try Another Quiz',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).popUntil((route) => route.isFirst);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Back to Home',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.05,
              shouldLoop: false,
              colors: const [
                AppColors.primaryGreen,
                AppColors.primaryBlue,
                AppColors.primaryOrange,
                AppColors.goldStar,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
