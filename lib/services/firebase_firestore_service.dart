import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_constants.dart';
import '../models/subject_model.dart';
import '../models/topic_model.dart';
import '../models/quiz_model.dart';

class FirebaseFirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== SUBJECTS ====================

  // Get all subjects
  Future<List<Subject>> getSubjects() async {
    try {
      final snapshot = await _firestore
          .collection('subjects')
          .orderBy('id')
          .get();

      return snapshot.docs
          .map((doc) => Subject.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting subjects: $e');
      return [];
    }
  }

  // Add a subject (admin function)
  Future<void> addSubject(Subject subject) async {
    try {
      await _firestore.collection('subjects').doc(subject.id.toString()).set({
        'id': subject.id,
        'name': subject.name,
        'description': subject.description,
        'icon': subject.icon,
      });
    } catch (e) {
      print('Error adding subject: $e');
    }
  }

  // ==================== TOPICS ====================

  // Get topics by subject
  Future<List<Topic>> getTopics(int subjectId) async {
    try {
      final snapshot = await _firestore
          .collection('topics')
          .where('subject_id', isEqualTo: subjectId)
          .get();

      final topics = snapshot.docs
          .map((doc) => Topic.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      
      // Sort by id client-side to avoid needing a composite index
      topics.sort((a, b) => a.id.compareTo(b.id));
      return topics;
    } catch (e) {
      print('Error getting topics: $e');
      return [];
    }
  }

  // Get topic detail
  Future<Topic?> getTopicDetail(int topicId) async {
    try {
      final doc = await _firestore
          .collection('topics')
          .doc(topicId.toString())
          .get();

      if (doc.exists) {
        return Topic.fromJson({...doc.data()!, 'id': doc.id});
      }
      return null;
    } catch (e) {
      print('Error getting topic detail: $e');
      return null;
    }
  }

  // Add a topic (admin function)
  Future<void> addTopic(Topic topic) async {
    try {
      await _firestore.collection('topics').doc(topic.id.toString()).set({
        'id': topic.id,
        'subject_id': topic.subjectId,
        'title': topic.title,
        'content': topic.content,
        'video_url': topic.videoUrl,
      });
    } catch (e) {
      print('Error adding topic: $e');
    }
  }

  // Add topic with raw fields (admin)
  Future<void> addTopicWithData({
    required int id,
    required int subjectId,
    required String title,
    required String content,
    String? videoUrl,
  }) async {
    await _firestore.collection('topics').doc(id.toString()).set({
      'id': id,
      'subject_id': subjectId,
      'title': title,
      'content': content,
      'video_url': videoUrl,
    });
  }

  // Update topic (admin)
  Future<void> updateTopic({
    required int id,
    required String title,
    required String content,
    String? videoUrl,
  }) async {
    await _firestore.collection('topics').doc(id.toString()).update({
      'title': title,
      'content': content,
      'video_url': videoUrl,
    });
  }

  // Delete topic (admin)
  Future<void> deleteTopic(int id) async {
    await _firestore.collection('topics').doc(id.toString()).delete();
  }

  // Scrape topic content from URL via backend, save full content to Firestore
  Future<String?> scrapeTopicContent(String url, {required int topicId}) async {
    try {
      final http.Response response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.adminScrape}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic_id': topicId.toString(), 'url': url}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final fullContent = data['content'] as String? ?? '';
          // Save full content to Firestore
          if (fullContent.isNotEmpty && topicId > 0) {
            await _firestore.collection('topics').doc(topicId.toString()).update({
              'content': fullContent,
              'source_url': url,
            });
          }
          return fullContent;
        }
      }
      return null;
    } catch (e) {
      print('Scrape error: $e');
      return null;
    }
  }

  // Auto-fetch notes from GFG by topic title (no URL needed), cache in Firestore
  Future<String?> autoFetchNotes({required int topicId, required String topicTitle, String subject = ''}) async {
    try {
      final http.Response response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.autoFetchNotes}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic_title': topicTitle, 'subject': subject}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final content = data['content'] as String? ?? '';
          if (content.isNotEmpty && topicId > 0) {
            // Cache in Firestore so next open is instant
            await _firestore.collection('topics').doc(topicId.toString()).update({
              'content': content,
              'source_url': data['source'] ?? '',
            });
          }
          return content;
        }
      }
      return null;
    } catch (e) {
      print('Auto-fetch notes error: $e');
      return null;
    }
  }

  // ==================== QUIZZES ====================

  // Get quiz questions for a topic
  Future<List<QuizQuestion>> getQuizQuestions(int topicId, int count) async {
    try {
      final snapshot = await _firestore
          .collection('quiz_questions')
          .where('topic_id', isEqualTo: topicId)
          .limit(count)
          .get();

      return snapshot.docs
          .map((doc) => QuizQuestion.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
    } catch (e) {
      print('Error getting quiz questions: $e');
      return [];
    }
  }

  // Save quiz result and update user stats (XP, quizzes_taken, streak)
  Future<void> saveQuizResult({
    required String userId,
    required int topicId,
    required int score,
    required int totalQuestions,
    required List<Map<String, dynamic>> answers,
  }) async {
    try {
      final batch = _firestore.batch();

      // Save quiz result
      final resultRef = _firestore.collection('quiz_results').doc();
      batch.set(resultRef, {
        'user_id': userId,
        'topic_id': topicId,
        'score': score,
        'total_questions': totalQuestions,
        'percentage': (score / totalQuestions * 100).round(),
        'answers': answers,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update user stats atomically
      final userRef = _firestore.collection('users').doc(userId);
      batch.update(userRef, {
        'total_xp': FieldValue.increment(score),
        'quizzes_taken': FieldValue.increment(1),
      });

      await batch.commit();

      // Update streak separately (needs current data)
      await _updateStreak(userId);
    } catch (e) {
      print('Error saving quiz result: $e');
    }
  }

  Future<void> _updateStreak(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final lastActive = data['last_active_date'] as Timestamp?;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (lastActive == null) {
        await _firestore.collection('users').doc(userId).update({
          'streak_days': 1,
          'last_active_date': Timestamp.fromDate(today),
        });
        return;
      }

      final lastDate = lastActive.toDate();
      final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDay).inDays;

      if (diff == 0) return; // already updated today
      if (diff == 1) {
        // consecutive day
        await _firestore.collection('users').doc(userId).update({
          'streak_days': FieldValue.increment(1),
          'last_active_date': Timestamp.fromDate(today),
        });
      } else {
        // streak broken
        await _firestore.collection('users').doc(userId).update({
          'streak_days': 1,
          'last_active_date': Timestamp.fromDate(today),
        });
      }
    } catch (e) {
      print('Error updating streak: $e');
    }
  }

  // Get user quiz results
  Future<List<Map<String, dynamic>>> getUserQuizResults(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('quiz_results')
          .where('user_id', isEqualTo: userId)
          .limit(20)
          .get();

      final results = snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
      // Sort client-side by timestamp descending
      results.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
      return results;
    } catch (e) {
      print('Error getting quiz results: $e');
      return [];
    }
  }

  // ==================== ANALYTICS ====================

  // Get user dashboard data
  Future<Map<String, dynamic>> getUserDashboard(String userId) async {
    try {
      final results = await getUserQuizResults(userId);

      if (results.isEmpty) {
        return {
          'total_quizzes': 0,
          'average_score': 0.0,
          'overall_accuracy': 0.0,
          'weak_subtopics': [],
          'recent_activity': [],
        };
      }

      // Calculate stats
      int totalQuizzes = results.length;
      double totalScore = 0;
      int totalQuestions = 0;
      int correctAnswers = 0;

      for (var result in results) {
        totalScore += (result['percentage'] ?? 0).toDouble();
        totalQuestions += (result['total_questions'] ?? 0) as int;
        correctAnswers += (result['score'] ?? 0) as int;
      }

      double averageScore = totalScore / totalQuizzes;
      double overallAccuracy = (correctAnswers / totalQuestions) * 100;

      // Get recent activity
      List<Map<String, dynamic>> recentActivity = results.take(5).map((result) {
        return {
          'type': 'quiz',
          'topic': 'Topic ${result['topic_id']}',
          'score': result['percentage'],
          'timestamp': result['timestamp']?.toDate().toIso8601String() ?? '',
        };
      }).toList();

      return {
        'total_quizzes': totalQuizzes,
        'average_score': averageScore,
        'overall_accuracy': overallAccuracy,
        'weak_subtopics': [],
        'recent_activity': recentActivity,
      };
    } catch (e) {
      print('Error getting dashboard: $e');
      return {
        'total_quizzes': 0,
        'average_score': 0.0,
        'overall_accuracy': 0.0,
        'weak_subtopics': [],
        'recent_activity': [],
      };
    }
  }

  // ==================== USER STATS ====================

  // Get user stats (xp, streak, quizzes_taken) from users collection
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        return {
          'total_xp': data['total_xp'] ?? 0,
          'streak_days': data['streak_days'] ?? 0,
          'quizzes_taken': data['quizzes_taken'] ?? 0,
        };
      }
      return {'total_xp': 0, 'streak_days': 0, 'quizzes_taken': 0};
    } catch (e) {
      print('Error getting user stats: $e');
      return {'total_xp': 0, 'streak_days': 0, 'quizzes_taken': 0};
    }
  }

  // Save last visited topic
  Future<void> saveLastVisitedTopic({
    required String userId,
    required int topicId,
    required String topicTitle,
    required String subjectName,
    required int subjectId,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'last_visited_topic': {
          'topic_id': topicId,
          'topic_title': topicTitle,
          'subject_name': subjectName,
          'subject_id': subjectId,
          'visited_at': FieldValue.serverTimestamp(),
        },
      });
    } catch (e) {
      print('Error saving last visited topic: $e');
    }
  }

  // Get XP earned today (sum of scores from quiz_results with today's date)
  Future<int> getTodayXp(String userId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final snapshot = await _firestore
          .collection('quiz_results')
          .where('user_id', isEqualTo: userId)
          .get();
      int total = 0;
      for (final doc in snapshot.docs) {
        final ts = doc.data()['timestamp'];
        if (ts == null) continue;
        final date = (ts as Timestamp).toDate();
        if (date.isAfter(startOfDay)) {
          total += (doc.data()['score'] as num?)?.toInt() ?? 0;
        }
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  // Get last visited topic
  Future<Map<String, dynamic>?> getLastVisitedTopic(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['last_visited_topic'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error getting last visited topic: $e');
      return null;
    }
  }

  // Get topic progress (best quiz score for a topic)
  Future<int> getTopicProgress(String userId, int topicId) async {
    try {
      final snapshot = await _firestore
          .collection('quiz_results')
          .where('user_id', isEqualTo: userId)
          .where('topic_id', isEqualTo: topicId)
          .get();
      if (snapshot.docs.isNotEmpty) {
        // Get best score client-side
        int best = 0;
        for (final doc in snapshot.docs) {
          final pct = (doc.data()['percentage'] ?? 0) as int;
          if (pct > best) best = pct;
        }
        return best;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Get progress for all topics in a subject for a user
  // Returns map of topicId -> best quiz percentage (0-100)
  Future<Map<int, int>> getSubjectProgress(String userId, int subjectId) async {
    try {
      final topics = await getTopics(subjectId);
      if (topics.isEmpty) return {};
      final topicIds = topics.map((t) => t.id).toList();

      final snapshot = await _firestore
          .collection('quiz_results')
          .where('user_id', isEqualTo: userId)
          .get();

      final Map<int, int> progress = {for (final id in topicIds) id: 0};
      for (final doc in snapshot.docs) {
        final topicId = (doc.data()['topic_id'] as num?)?.toInt() ?? 0;
        if (progress.containsKey(topicId)) {
          final pct = (doc.data()['percentage'] as num?)?.toInt() ?? 0;
          if (pct > (progress[topicId] ?? 0)) progress[topicId] = pct;
        }
      }
      return progress;
    } catch (e) {
      print('Error getting subject progress: $e');
      return {};
    }
  }

  // ==================== ADMIN FUNCTIONS ====================

  // Get all users (admin)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      print('Error getting users: $e');
      return [];
    }
  }

  // Update user role (admin)
  Future<void> updateUserRole(String userId, String role) async {
    await _firestore.collection('users').doc(userId).update({'role': role});
  }

  // Get quiz questions for admin (returns raw maps)
  Future<List<Map<String, dynamic>>> getQuizQuestionsAdmin(int topicId) async {
    try {
      final snapshot = await _firestore
          .collection('quiz_questions')
          .where('topic_id', isEqualTo: topicId)
          .get();
      return snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      print('Error getting quiz questions: $e');
      return [];
    }
  }

  // Add quiz question (admin)
  Future<void> addQuizQuestion({
    required int topicId,
    required String question,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctAnswer,
  }) async {
    await _firestore.collection('quiz_questions').add({
      'topic_id': topicId,
      'question_text': question,
      'option_a': optionA,
      'option_b': optionB,
      'option_c': optionC,
      'option_d': optionD,
      'correct_answer': correctAnswer,
      'subtopic': '',
    });
  }

  // Delete quiz question (admin)
  Future<void> deleteQuizQuestion(String id) async {
    await _firestore.collection('quiz_questions').doc(id).delete();
  }

  // Initialize database with sample data
  Future<void> initializeSampleData() async {
    try {
      final subjects = [
        {'id': 1, 'name': 'Data Structures & Algorithms', 'description': 'Learn DSA', 'icon': 'tree'},
        {'id': 2, 'name': 'Database Management Systems', 'description': 'Learn DBMS', 'icon': 'storage'},
        {'id': 3, 'name': 'Operating Systems', 'description': 'Learn OS', 'icon': 'computer'},
        {'id': 4, 'name': 'Computer Networks', 'description': 'Learn CN', 'icon': 'network'},
        {'id': 5, 'name': 'Python Programming', 'description': 'Learn Python', 'icon': 'code'},
        {'id': 6, 'name': 'Java Programming', 'description': 'Learn Java', 'icon': 'coffee'},
      ];
      for (var subject in subjects) {
        await _firestore.collection('subjects').doc(subject['id'].toString()).set(subject);
      }
      print('Sample data initialized successfully');
    } catch (e) {
      print('Error initializing sample data: $e');
    }
  }

  // Seed topics for all subjects
  Future<void> seedTopics() async {
    try {
      final topics = [
        // DSA (subject_id: 1)
        {'id': 101, 'subject_id': 1, 'title': 'Arrays & Strings', 'content': 'Arrays are contiguous memory locations. Learn about 1D/2D arrays, string manipulation, sliding window, and two-pointer techniques.', 'video_url': null},
        {'id': 102, 'subject_id': 1, 'title': 'Linked Lists', 'content': 'A linked list is a linear data structure where elements are stored in nodes. Covers singly, doubly, and circular linked lists with operations like insertion, deletion, and reversal.', 'video_url': null},
        {'id': 103, 'subject_id': 1, 'title': 'Stacks & Queues', 'content': 'Stack follows LIFO and Queue follows FIFO. Learn about implementation using arrays/linked lists, monotonic stacks, deques, and priority queues.', 'video_url': null},
        {'id': 104, 'subject_id': 1, 'title': 'Trees & Binary Trees', 'content': 'Trees are hierarchical data structures. Covers binary trees, BST, AVL trees, tree traversals (inorder, preorder, postorder), and common tree problems.', 'video_url': null},
        {'id': 105, 'subject_id': 1, 'title': 'Graphs', 'content': 'Graphs consist of vertices and edges. Learn BFS, DFS, shortest path algorithms (Dijkstra, Bellman-Ford), and minimum spanning trees (Kruskal, Prim).', 'video_url': null},
        {'id': 106, 'subject_id': 1, 'title': 'Sorting Algorithms', 'content': 'Covers bubble sort, selection sort, insertion sort, merge sort, quick sort, and heap sort with time and space complexity analysis.', 'video_url': null},
        {'id': 107, 'subject_id': 1, 'title': 'Dynamic Programming', 'content': 'DP solves problems by breaking them into overlapping subproblems. Covers memoization, tabulation, knapsack, LCS, LIS, and coin change problems.', 'video_url': null},
        {'id': 108, 'subject_id': 1, 'title': 'Hashing', 'content': 'Hash tables provide O(1) average lookup. Learn hash functions, collision resolution (chaining, open addressing), and common hashing problems.', 'video_url': null},
        {'id': 109, 'subject_id': 1, 'title': 'Recursion & Backtracking', 'content': 'Recursion solves problems by calling itself. Backtracking explores all possibilities and prunes invalid paths. Covers N-Queens, Sudoku, and permutations.', 'video_url': null},
        {'id': 110, 'subject_id': 1, 'title': 'Heaps & Priority Queues', 'content': 'A heap is a complete binary tree satisfying the heap property. Learn min-heap, max-heap, heap operations, and applications like top-K problems.', 'video_url': null},
        {'id': 111, 'subject_id': 1, 'title': 'Tries', 'content': 'A trie is a tree-like data structure for storing strings. Learn insertion, search, prefix matching, and applications in autocomplete and spell checking.', 'video_url': null},
        {'id': 112, 'subject_id': 1, 'title': 'Greedy Algorithms', 'content': 'Greedy algorithms make locally optimal choices at each step. Covers activity selection, fractional knapsack, Huffman coding, and interval scheduling.', 'video_url': null},

        // DBMS (subject_id: 2)
        {'id': 201, 'subject_id': 2, 'title': 'Introduction to DBMS', 'content': 'A Database Management System is software for storing and retrieving data. Covers DBMS vs file systems, advantages, types of databases, and database users.', 'video_url': null},
        {'id': 202, 'subject_id': 2, 'title': 'ER Model', 'content': 'Entity-Relationship model is a conceptual data model. Learn entities, attributes, relationships, cardinality, participation constraints, and ER diagrams.', 'video_url': null},
        {'id': 203, 'subject_id': 2, 'title': 'Relational Model', 'content': 'The relational model organizes data into tables. Covers relations, tuples, attributes, keys (primary, foreign, candidate), and relational algebra.', 'video_url': null},
        {'id': 204, 'subject_id': 2, 'title': 'SQL Basics', 'content': 'SQL is the standard language for relational databases. Covers DDL (CREATE, ALTER, DROP), DML (SELECT, INSERT, UPDATE, DELETE), and basic queries.', 'video_url': null},
        {'id': 205, 'subject_id': 2, 'title': 'Advanced SQL', 'content': 'Advanced SQL covers JOINs (inner, outer, cross), subqueries, aggregate functions, GROUP BY, HAVING, window functions, and stored procedures.', 'video_url': null},
        {'id': 206, 'subject_id': 2, 'title': 'Normalization', 'content': 'Normalization reduces data redundancy. Covers functional dependencies, 1NF, 2NF, 3NF, BCNF, and decomposition with lossless join property.', 'video_url': null},
        {'id': 207, 'subject_id': 2, 'title': 'Transactions & ACID', 'content': 'A transaction is a unit of work. Learn ACID properties (Atomicity, Consistency, Isolation, Durability), transaction states, and concurrency control.', 'video_url': null},
        {'id': 208, 'subject_id': 2, 'title': 'Indexing & Hashing', 'content': 'Indexes speed up data retrieval. Covers dense/sparse indexes, B-tree indexes, hash-based indexing, and query optimization using indexes.', 'video_url': null},
        {'id': 209, 'subject_id': 2, 'title': 'Concurrency Control', 'content': 'Concurrency control manages simultaneous transactions. Covers lock-based protocols, two-phase locking, timestamp ordering, and deadlock handling.', 'video_url': null},
        {'id': 210, 'subject_id': 2, 'title': 'NoSQL Databases', 'content': 'NoSQL databases handle unstructured data. Covers document stores (MongoDB), key-value stores (Redis), column stores (Cassandra), and graph databases.', 'video_url': null},

        // OS (subject_id: 3)
        {'id': 301, 'subject_id': 3, 'title': 'Introduction to OS', 'content': 'An Operating System manages hardware and software resources. Covers OS functions, types (batch, time-sharing, real-time), kernel, and system calls.', 'video_url': null},
        {'id': 302, 'subject_id': 3, 'title': 'Process Management', 'content': 'A process is a program in execution. Learn process states, PCB, process creation/termination, context switching, and inter-process communication.', 'video_url': null},
        {'id': 303, 'subject_id': 3, 'title': 'CPU Scheduling', 'content': 'CPU scheduling decides which process runs next. Covers FCFS, SJF, Round Robin, Priority scheduling, multilevel queues, and scheduling criteria.', 'video_url': null},
        {'id': 304, 'subject_id': 3, 'title': 'Threads & Concurrency', 'content': 'Threads are lightweight processes sharing the same memory. Covers multithreading models, thread libraries (POSIX, Java), and synchronization.', 'video_url': null},
        {'id': 305, 'subject_id': 3, 'title': 'Process Synchronization', 'content': 'Synchronization prevents race conditions. Covers critical section problem, mutex, semaphores, monitors, and classic problems (producer-consumer, dining philosophers).', 'video_url': null},
        {'id': 306, 'subject_id': 3, 'title': 'Deadlocks', 'content': 'A deadlock occurs when processes wait for each other indefinitely. Covers necessary conditions, resource allocation graphs, prevention, avoidance (Banker\'s algorithm), and detection.', 'video_url': null},
        {'id': 307, 'subject_id': 3, 'title': 'Memory Management', 'content': 'Memory management allocates RAM to processes. Covers contiguous allocation, fragmentation, paging, segmentation, and address translation.', 'video_url': null},
        {'id': 308, 'subject_id': 3, 'title': 'Virtual Memory', 'content': 'Virtual memory allows processes to use more memory than physically available. Covers demand paging, page faults, page replacement algorithms (FIFO, LRU, Optimal).', 'video_url': null},
        {'id': 309, 'subject_id': 3, 'title': 'File Systems', 'content': 'File systems organize data on storage devices. Covers file attributes, directory structures, file allocation methods (contiguous, linked, indexed), and free space management.', 'video_url': null},
        {'id': 310, 'subject_id': 3, 'title': 'I/O Systems', 'content': 'I/O management handles communication with devices. Covers I/O hardware, polling, interrupts, DMA, disk scheduling algorithms (FCFS, SSTF, SCAN, C-SCAN).', 'video_url': null},

        // CN (subject_id: 4)
        {'id': 401, 'subject_id': 4, 'title': 'Network Fundamentals', 'content': 'Computer networks connect devices to share resources. Covers network types (LAN, WAN, MAN), topologies, transmission media, and bandwidth vs latency.', 'video_url': null},
        {'id': 402, 'subject_id': 4, 'title': 'OSI Model', 'content': 'The OSI model has 7 layers: Physical, Data Link, Network, Transport, Session, Presentation, Application. Learn each layer\'s functions and protocols.', 'video_url': null},
        {'id': 403, 'subject_id': 4, 'title': 'TCP/IP Model', 'content': 'TCP/IP is the foundation of the internet with 4 layers. Covers the differences from OSI, IP addressing, subnetting, and CIDR notation.', 'video_url': null},
        {'id': 404, 'subject_id': 4, 'title': 'IP Addressing & Subnetting', 'content': 'IP addresses identify devices on a network. Covers IPv4 vs IPv6, classes, private/public IPs, subnet masks, VLSM, and subnetting calculations.', 'video_url': null},
        {'id': 405, 'subject_id': 4, 'title': 'Routing Protocols', 'content': 'Routing determines the path for data packets. Covers static vs dynamic routing, RIP, OSPF, BGP, distance vector vs link state algorithms.', 'video_url': null},
        {'id': 406, 'subject_id': 4, 'title': 'TCP & UDP', 'content': 'TCP provides reliable, ordered delivery. UDP is faster but unreliable. Covers TCP handshake, flow control, congestion control, and when to use each.', 'video_url': null},
        {'id': 407, 'subject_id': 4, 'title': 'Application Layer Protocols', 'content': 'Application layer protocols enable user services. Covers HTTP/HTTPS, DNS, DHCP, FTP, SMTP, POP3, IMAP, and how they work.', 'video_url': null},
        {'id': 408, 'subject_id': 4, 'title': 'Network Security', 'content': 'Network security protects data in transit. Covers firewalls, VPNs, SSL/TLS, encryption, authentication, common attacks (DDoS, MITM), and prevention.', 'video_url': null},
        {'id': 409, 'subject_id': 4, 'title': 'Wireless Networks', 'content': 'Wireless networks use radio waves for communication. Covers WiFi standards (802.11), Bluetooth, cellular networks (4G/5G), and wireless security.', 'video_url': null},
        {'id': 410, 'subject_id': 4, 'title': 'Socket Programming', 'content': 'Sockets enable network communication between programs. Covers TCP sockets, UDP sockets, client-server model, and basic socket programming concepts.', 'video_url': null},

        // Python (subject_id: 5)
        {'id': 501, 'subject_id': 5, 'title': 'Python Basics', 'content': 'Python is a high-level, interpreted language. Covers variables, data types (int, float, str, bool), operators, input/output, and basic syntax.', 'video_url': null},
        {'id': 502, 'subject_id': 5, 'title': 'Control Flow', 'content': 'Control flow directs program execution. Covers if/elif/else statements, for loops, while loops, break, continue, pass, and nested control structures.', 'video_url': null},
        {'id': 503, 'subject_id': 5, 'title': 'Functions', 'content': 'Functions are reusable blocks of code. Covers defining functions, parameters, return values, default arguments, *args, **kwargs, and lambda functions.', 'video_url': null},
        {'id': 504, 'subject_id': 5, 'title': 'Data Structures in Python', 'content': 'Python has built-in data structures. Covers lists, tuples, sets, dictionaries, list comprehensions, and common operations on each structure.', 'video_url': null},
        {'id': 505, 'subject_id': 5, 'title': 'Object-Oriented Programming', 'content': 'OOP organizes code into objects. Covers classes, objects, constructors (__init__), inheritance, polymorphism, encapsulation, and dunder methods.', 'video_url': null},
        {'id': 506, 'subject_id': 5, 'title': 'File Handling', 'content': 'Python can read and write files. Covers opening files (open()), reading (read, readline, readlines), writing, appending, and the with statement.', 'video_url': null},
        {'id': 507, 'subject_id': 5, 'title': 'Exception Handling', 'content': 'Exception handling manages runtime errors. Covers try/except/finally, raising exceptions, custom exceptions, and common built-in exceptions.', 'video_url': null},
        {'id': 508, 'subject_id': 5, 'title': 'Modules & Packages', 'content': 'Modules organize Python code into files. Covers importing modules, creating packages, pip, virtual environments, and popular standard library modules.', 'video_url': null},
        {'id': 509, 'subject_id': 5, 'title': 'Decorators & Generators', 'content': 'Decorators modify function behavior. Generators produce values lazily. Covers @decorator syntax, functools.wraps, yield, generator expressions, and itertools.', 'video_url': null},
        {'id': 510, 'subject_id': 5, 'title': 'NumPy & Pandas Basics', 'content': 'NumPy provides fast array operations. Pandas offers data manipulation tools. Covers ndarray, DataFrame, Series, indexing, filtering, and basic data analysis.', 'video_url': null},

        // Java (subject_id: 6)
        {'id': 601, 'subject_id': 6, 'title': 'Java Basics', 'content': 'Java is a platform-independent, object-oriented language. Covers JVM, JDK, JRE, data types, variables, operators, and the structure of a Java program.', 'video_url': null},
        {'id': 602, 'subject_id': 6, 'title': 'Control Statements', 'content': 'Java control statements direct program flow. Covers if/else, switch, for, while, do-while loops, break, continue, and labeled statements.', 'video_url': null},
        {'id': 603, 'subject_id': 6, 'title': 'Arrays & Strings', 'content': 'Arrays store multiple values of the same type. Covers 1D/2D arrays, String class, StringBuilder, common string methods, and array manipulation.', 'video_url': null},
        {'id': 604, 'subject_id': 6, 'title': 'OOP Concepts', 'content': 'Java is built on OOP principles. Covers classes, objects, constructors, this keyword, static members, access modifiers, and method overloading.', 'video_url': null},
        {'id': 605, 'subject_id': 6, 'title': 'Inheritance & Polymorphism', 'content': 'Inheritance allows code reuse. Polymorphism enables one interface for multiple implementations. Covers extends, super, method overriding, and abstract classes.', 'video_url': null},
        {'id': 606, 'subject_id': 6, 'title': 'Interfaces & Abstract Classes', 'content': 'Interfaces define contracts. Abstract classes provide partial implementation. Covers interface syntax, default methods, functional interfaces, and when to use each.', 'video_url': null},
        {'id': 607, 'subject_id': 6, 'title': 'Exception Handling', 'content': 'Java exception handling manages errors. Covers checked vs unchecked exceptions, try/catch/finally, throws, throw, custom exceptions, and exception hierarchy.', 'video_url': null},
        {'id': 608, 'subject_id': 6, 'title': 'Collections Framework', 'content': 'Java Collections provide data structures. Covers List (ArrayList, LinkedList), Set (HashSet, TreeSet), Map (HashMap, TreeMap), and Iterator.', 'video_url': null},
        {'id': 609, 'subject_id': 6, 'title': 'Generics & Lambda', 'content': 'Generics enable type-safe code. Lambda expressions simplify functional programming. Covers generic classes/methods, bounded types, and Stream API basics.', 'video_url': null},
        {'id': 610, 'subject_id': 6, 'title': 'Multithreading', 'content': 'Java supports concurrent execution via threads. Covers Thread class, Runnable interface, synchronization, wait/notify, ExecutorService, and thread safety.', 'video_url': null},
      ];

      for (var topic in topics) {
        await _firestore.collection('topics').doc(topic['id'].toString()).set(topic);
      }
      print('Topics seeded successfully: ${topics.length} topics added');
    } catch (e) {
      print('Error seeding topics: $e');
      rethrow;
    }
  }
}
