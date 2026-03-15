class CodingProblem {
  final int id;
  final int topicId;
  final String title;
  final String description;
  final String difficulty;
  final List<TestCase> testCases;

  CodingProblem({
    required this.id,
    required this.topicId,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.testCases,
  });

  factory CodingProblem.fromJson(Map<String, dynamic> json) {
    return CodingProblem(
      id: json['id'],
      topicId: json['topic_id'],
      title: json['title'],
      description: json['description'],
      difficulty: json['difficulty'] ?? 'Medium',
      testCases: (json['test_cases'] as List?)
              ?.map((tc) => TestCase.fromJson(tc))
              .toList() ??
          [],
    );
  }
}

class TestCase {
  final String input;
  final String expectedOutput;

  TestCase({
    required this.input,
    required this.expectedOutput,
  });

  factory TestCase.fromJson(Map<String, dynamic> json) {
    return TestCase(
      input: json['input'].toString(),
      expectedOutput: json['expected_output'].toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'input': input,
      'expected_output': expectedOutput,
    };
  }
}

class CodeExecutionResult {
  final bool success;
  final List<TestResult> results;
  final int? executionTime;
  final String? error;

  CodeExecutionResult({
    required this.success,
    required this.results,
    this.executionTime,
    this.error,
  });

  factory CodeExecutionResult.fromJson(Map<String, dynamic> json) {
    return CodeExecutionResult(
      success: json['success'] ?? false,
      results: (json['results'] as List?)
              ?.map((r) => TestResult.fromJson(r))
              .toList() ??
          [],
      executionTime: json['execution_time'],
      error: json['error'],
    );
  }
}

class TestResult {
  final int testCaseId;
  final bool passed;
  final String? actualOutput;
  final String? expectedOutput;
  final String? error;

  TestResult({
    required this.testCaseId,
    required this.passed,
    this.actualOutput,
    this.expectedOutput,
    this.error,
  });

  factory TestResult.fromJson(Map<String, dynamic> json) {
    return TestResult(
      testCaseId: json['test_case_id'] ?? 0,
      passed: json['passed'] ?? false,
      actualOutput: json['actual_output'],
      expectedOutput: json['expected_output'],
      error: json['error'],
    );
  }
}
