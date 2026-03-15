import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../services/firebase_firestore_service.dart';

// Firestore Service Provider
final firestoreServiceProvider = Provider<FirebaseFirestoreService>((ref) {
  return FirebaseFirestoreService();
});

// Subjects Provider
final subjectsProvider = FutureProvider<List<Subject>>((ref) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getSubjects();
});

// Topics Provider (by subject)
final topicsProvider = FutureProvider.family<List<Topic>, int>((ref, subjectId) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getTopics(subjectId);
});

// Topic Detail Provider
final topicDetailProvider = FutureProvider.family<Topic, int>((ref, topicId) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  final topic = await firestoreService.getTopicDetail(topicId);
  if (topic == null) {
    throw Exception('Topic not found');
  }
  return topic;
});

// Dashboard Provider
final dashboardProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getUserDashboard(userId);
});

// User Stats Provider (xp, streak, quizzes_taken)
final userStatsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getUserStats(userId);
});

// Last Visited Topic Provider
final lastVisitedTopicProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, userId) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getLastVisitedTopic(userId);
});

// Topic Progress Provider (best quiz score %)
final topicProgressProvider = FutureProvider.family<int, ({String userId, int topicId})>((ref, args) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getTopicProgress(args.userId, args.topicId);
});

// Subject Progress Provider — returns map of topicId -> best score %
final subjectProgressProvider = FutureProvider.family<Map<int, int>, ({String userId, int subjectId})>((ref, args) async {
  final firestoreService = ref.read(firestoreServiceProvider);
  return await firestoreService.getSubjectProgress(args.userId, args.subjectId);
});
