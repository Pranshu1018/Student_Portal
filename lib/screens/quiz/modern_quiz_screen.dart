import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/api_constants.dart';
import '../../models/quiz_model.dart';
import '../../services/firebase_firestore_service.dart';
import '../../providers/auth_provider.dart';
import 'modern_quiz_result_screen.dart';

class ModernQuizScreen extends ConsumerStatefulWidget {
  final int topicId;
  final String topicTitle;

  const ModernQuizScreen({
    super.key,
    required this.topicId,
    required this.topicTitle,
  });

  @override
  ConsumerState<ModernQuizScreen> createState() => _ModernQuizScreenState();
}

class _ModernQuizScreenState extends ConsumerState<ModernQuizScreen> {
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();
  late ConfettiController _confettiController;
  
  List<QuizQuestion> _questions = [];
  Map<int, String> _answers = {}; // questionIndex -> selected letter
  int _currentQuestionIndex = 0;
  bool _isLoading = true;
  String? _selectedAnswer;
  bool _showFeedback = false;
  
  // Timer
  Timer? _timer;
  int _timeRemaining = 600; // 10 minutes
  
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadQuiz();
    _startTimer();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining > 0) {
        setState(() => _timeRemaining--);
      } else {
        _submitQuiz();
      }
    });
  }

  Future<void> _loadQuiz() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.liveQuiz(widget.topicId.toString())}');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawQuestions = List<Map<String, dynamic>>.from(data['questions']);
        final questions = rawQuestions.map((q) => QuizQuestion.fromJson({
          'id': q['quizId'] ?? '0',
          'question_text': q['question'] ?? '',
          'option_a': q['optionA'] ?? '',
          'option_b': q['optionB'] ?? '',
          'option_c': q['optionC'] ?? '',
          'option_d': q['optionD'] ?? '',
          'correct_answer': q['correctAnswer'] ?? 'A',
        })).toList();

        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      } else {
        final err = jsonDecode(response.body);
        throw Exception(err['detail'] ?? 'Failed to load quiz');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
      _showFeedback = true;
    });

    // Show confetti for correct answer
    final question = _questions[_currentQuestionIndex];
    if (answer == question.correctAnswer) {
      _confettiController.play();
    }

    // Auto-advance after 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _nextQuestion() {
    if (_selectedAnswer != null) {
      _answers[_currentQuestionIndex] = _selectedAnswer!;
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswer = null;
        _showFeedback = false;
      });
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    _timer?.cancel();

    // Calculate score
    int correctCount = 0;
    final List<Map<String, dynamic>> answersList = [];
    for (int i = 0; i < _questions.length; i++) {
      final selected = _answers[i] ?? '';
      final correct = _questions[i].correctAnswer;
      final isCorrect = selected == correct;
      if (isCorrect) correctCount++;
      answersList.add({
        'question_id': _questions[i].id,
        'selected_answer': selected,
        'correct_answer': correct,
        'is_correct': isCorrect,
      });
    }

    final totalQuestions = _questions.length;
    final wrongCount = totalQuestions - correctCount;
    final scorePercent = totalQuestions > 0
        ? (correctCount / totalQuestions * 100).roundToDouble()
        : 0.0;

    // Save to Firestore
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      await _firestoreService.saveQuizResult(
        userId: userId,
        topicId: widget.topicId,
        score: correctCount,
        totalQuestions: totalQuestions,
        answers: answersList,
      );
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ModernQuizResultScreen(
            score: scorePercent,
            correctCount: correctCount,
            wrongCount: wrongCount,
            weakSubtopics: const [],
            topicTitle: widget.topicTitle,
          ),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryGreen, AppColors.primaryBlue],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text(
                  'Fetching quiz...',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'This takes about 5-10 seconds',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz')),
        body: const Center(child: Text('No questions available')),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryGreen, Colors.white],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header with Timer
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        
                        // Question Counter
                        FadeInDown(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_currentQuestionIndex + 1}/${_questions.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        
                        // Timer
                        FadeInDown(
                          delay: const Duration(milliseconds: 100),
                          child: CircularPercentIndicator(
                            radius: 25,
                            lineWidth: 4,
                            percent: _timeRemaining / 600,
                            center: Text(
                              _formatTime(_timeRemaining),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            progressColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            circularStrokeCap: CircularStrokeCap.round,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Question Card
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          FadeIn(
                            key: ValueKey(_currentQuestionIndex),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    question.questionText,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Options
                                  _buildOption('A', question.optionA),
                                  const SizedBox(height: 12),
                                  _buildOption('B', question.optionB),
                                  const SizedBox(height: 12),
                                  _buildOption('C', question.optionC),
                                  const SizedBox(height: 12),
                                  _buildOption('D', question.optionD),
                                ],
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

  Widget _buildOption(String letter, String text) {
    final isSelected = _selectedAnswer == letter;
    final question = _questions.isNotEmpty ? _questions[_currentQuestionIndex] : null;
    final isCorrect = question != null && letter == question.correctAnswer;
    final showCorrect = _showFeedback && isCorrect;
    final showWrong = _showFeedback && isSelected && !isCorrect;

    Color borderColor = Colors.transparent;
    Color bgColor = AppColors.backgroundLight;
    if (showCorrect) {
      borderColor = AppColors.success;
      bgColor = AppColors.success.withOpacity(0.1);
    } else if (showWrong) {
      borderColor = AppColors.error;
      bgColor = AppColors.error.withOpacity(0.1);
    } else if (isSelected) {
      borderColor = AppColors.primaryGreen;
      bgColor = AppColors.primaryGreen.withOpacity(0.1);
    }

    return BounceInUp(
      delay: Duration(milliseconds: 100 * (letter.codeUnitAt(0) - 65)),
      child: GestureDetector(
        onTap: _selectedAnswer == null ? () => _selectAnswer(letter) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryGreen : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (showCorrect)
                const Icon(Icons.check_circle, color: AppColors.success, size: 24),
              if (showWrong)
                const Icon(Icons.cancel, color: AppColors.error, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
