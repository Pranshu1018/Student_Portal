class ApiConstants {
  // Base URL - Update this with your backend URL
  static const String baseUrl = 'http://10.0.2.2:8000/api';

  
  // Auth Endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String verify = '/auth/verify';
  
  // Content Endpoints
  static const String subjects = '/subjects';
  static String topicsBySubject(int subjectId) => '/subjects/$subjectId/topics';
  static String topicDetail(int topicId) => '/topics/$topicId';
  
  // Quiz Endpoints
  static const String quizStart = '/quiz/start';
  static const String quizSubmit = '/quiz/submit';
  static String liveQuiz(String topicId, {int count = 10}) => '/topics/$topicId/quiz?count=$count';
  
  // Code Execution Endpoints
  static const String codeExecute = '/code/execute';
  
  // Performance Endpoints
  static const String performanceDashboard = '/performance/dashboard';
  static const String performanceAnalytics = '/performance/analytics';
  
  // Admin Endpoints
  static const String adminSubjects = '/admin/subjects';
  static const String adminTopics = '/admin/topics';
  static const String adminQuestions = '/admin/questions';
  static const String adminScrape = '/admin/scrapeTopicContent';
  static const String autoFetchNotes = '/notes/fetch';
}
