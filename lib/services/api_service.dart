import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants/api_constants.dart';
import '../models/user_model.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';

class ApiService {
  final _storage = const FlutterSecureStorage();
  
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
  
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }
  
  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }
  
  Map<String, String> _getHeaders({bool requiresAuth = false, String? token}) {
    final headers = {
      'Content-Type': 'application/json',
    };
    
    if (requiresAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Authentication APIs
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.register}'),
      headers: _getHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );
    
    return jsonDecode(response.body);
  }
  
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: _getHeaders(),
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );
    
    final data = jsonDecode(response.body);
    
    if (data['success'] == true && data['token'] != null) {
      await saveToken(data['token']);
    }
    
    return data;
  }
  
  Future<Map<String, dynamic>> verifyToken() async {
    final token = await getToken();
    
    if (token == null) {
      return {'valid': false};
    }
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.verify}'),
      headers: _getHeaders(requiresAuth: true, token: token),
    );
    
    return jsonDecode(response.body);
  }
  
  // Content APIs
  Future<List<Subject>> getSubjects() async {
    final token = await getToken();
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.subjects}'),
      headers: _getHeaders(requiresAuth: true, token: token),
    );
    
    final data = jsonDecode(response.body);
    final subjects = (data['subjects'] as List)
        .map((json) => Subject.fromJson(json))
        .toList();
    
    return subjects;
  }
  
  Future<List<Topic>> getTopics(int subjectId) async {
    final token = await getToken();
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.topicsBySubject(subjectId)}'),
      headers: _getHeaders(requiresAuth: true, token: token),
    );
    
    final data = jsonDecode(response.body);
    final topics = (data['topics'] as List)
        .map((json) => Topic.fromJson(json))
        .toList();
    
    return topics;
  }
  
  Future<Topic> getTopicDetail(int topicId) async {
    final token = await getToken();
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.topicDetail(topicId)}'),
      headers: _getHeaders(requiresAuth: true, token: token),
    );
    
    final data = jsonDecode(response.body);
    return Topic.fromJson(data);
  }
  
  // Quiz APIs
  Future<Map<String, dynamic>> startQuiz(int topicId) async {
    final token = await getToken();
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.quizStart}'),
      headers: _getHeaders(requiresAuth: true, token: token),
      body: jsonEncode({'topic_id': topicId}),
    );
    
    return jsonDecode(response.body);
  }
  
  Future<Map<String, dynamic>> submitQuiz(String quizId, List<Map<String, dynamic>> answers) async {
    final token = await getToken();
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.quizSubmit}'),
      headers: _getHeaders(requiresAuth: true, token: token),
      body: jsonEncode({
        'quiz_id': quizId,
        'answers': answers,
      }),
    );
    
    return jsonDecode(response.body);
  }
  
  // Performance APIs
  Future<Map<String, dynamic>> getDashboard() async {
    final token = await getToken();
    
    final response = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.performanceDashboard}'),
      headers: _getHeaders(requiresAuth: true, token: token),
    );
    
    return jsonDecode(response.body);
  }
  
  // Code Execution API
  Future<Map<String, dynamic>> executeCode(
    String code,
    String language,
    List<Map<String, dynamic>> testCases,
  ) async {
    final token = await getToken();
    
    final response = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.codeExecute}'),
      headers: _getHeaders(requiresAuth: true, token: token),
      body: jsonEncode({
        'code': code,
        'language': language,
        'test_cases': testCases,
      }),
    );
    
    return jsonDecode(response.body);
  }
}
