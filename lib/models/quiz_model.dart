class QuizQuestion {
  final int id;
  final String questionText;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctAnswer;
  String? selectedAnswer;

  QuizQuestion({
    required this.id,
    required this.questionText,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctAnswer,
    this.selectedAnswer,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: int.tryParse(json['id'].toString()) ?? 0,
      questionText: json['question_text'] ?? '',
      optionA: json['option_a'] ?? '',
      optionB: json['option_b'] ?? '',
      optionC: json['option_c'] ?? '',
      optionD: json['option_d'] ?? '',
      correctAnswer: (json['correct_answer'] ?? 'A').toString().toUpperCase(),
    );
  }
}

class QuizResult {
  final double score;
  final int correctCount;
  final int wrongCount;
  final List<String> weakSubtopics;

  QuizResult({
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.weakSubtopics,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) {
    return QuizResult(
      score: (json['score'] as num).toDouble(),
      correctCount: json['correct_count'],
      wrongCount: json['wrong_count'],
      weakSubtopics: List<String>.from(json['weak_subtopics'] ?? []),
    );
  }
}
