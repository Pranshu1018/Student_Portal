import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_firestore_service.dart';
import '../auth/modern_login_screen.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestoreService _db = FirebaseFirestoreService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Welcome, ${user?.name ?? 'Admin'}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ModernLoginScreen()),
                );
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.topic), text: 'Topics'),
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.quiz), text: 'Quizzes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DashboardTab(db: _db),
          _TopicsTab(db: _db),
          _UsersTab(db: _db),
          _QuizzesTab(db: _db),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DASHBOARD TAB
// ─────────────────────────────────────────────
class _DashboardTab extends StatefulWidget {
  final FirebaseFirestoreService db;
  const _DashboardTab({required this.db});

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  bool _loading = true;
  int _subjectCount = 0;
  int _topicCount = 0;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final subjects = await widget.db.getSubjects();
    int topics = 0;
    for (final s in subjects) {
      final t = await widget.db.getTopics(s.id);
      topics += t.length;
    }
    if (mounted) {
      setState(() {
        _subjectCount = subjects.length;
        _topicCount = topics;
        _loading = false;
      });
    }
  }

  Future<void> _seedSubjects() async {
    setState(() => _status = 'Seeding subjects...');
    await widget.db.initializeSampleData();
    setState(() => _status = '✅ 6 subjects seeded!');
    _load();
  }

  Future<void> _seedTopics() async {
    setState(() => _status = 'Seeding topics...');
    await widget.db.seedTopics();
    setState(() => _status = '✅ 62 topics seeded!');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(label: 'Subjects', value: '$_subjectCount', icon: Icons.book, color: AppColors.primaryBlue),
              const SizedBox(width: 16),
              _StatCard(label: 'Topics', value: '$_topicCount', icon: Icons.topic, color: AppColors.primaryGreen),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Database Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Seed Subjects (6)',
            icon: Icons.upload,
            color: AppColors.primaryGreen,
            onTap: _seedSubjects,
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Seed Topics (62)',
            icon: Icons.topic,
            color: AppColors.primaryBlue,
            onTap: _seedTopics,
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _status.contains('✅') ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _status.contains('✅') ? Colors.green : Colors.orange),
              ),
              child: Text(_status, style: TextStyle(color: _status.contains('✅') ? Colors.green.shade800 : Colors.orange.shade800)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TOPICS TAB
// ─────────────────────────────────────────────
class _TopicsTab extends StatefulWidget {
  final FirebaseFirestoreService db;
  const _TopicsTab({required this.db});

  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends State<_TopicsTab> {
  int _selectedSubjectId = 1;
  List<Map<String, dynamic>> _subjects = [];
  List<dynamic> _topics = [];
  bool _loading = true;

  final _subjectNames = {
    1: 'DSA', 2: 'DBMS', 3: 'OS', 4: 'CN', 5: 'Python', 6: 'Java',
  };

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    final subjects = await widget.db.getSubjects();
    setState(() {
      _subjects = subjects.map((s) => {'id': s.id, 'name': s.name}).toList();
      if (_subjects.isNotEmpty) _selectedSubjectId = _subjects.first['id'];
    });
    await _loadTopics();
  }

  Future<void> _loadTopics() async {
    setState(() => _loading = true);
    final topics = await widget.db.getTopics(_selectedSubjectId);
    setState(() { _topics = topics; _loading = false; });
  }

  void _showAddEditDialog({dynamic topic}) {
    final titleCtrl = TextEditingController(text: topic?.title ?? '');
    final contentCtrl = TextEditingController(text: topic?.content ?? '');
    final videoCtrl = TextEditingController(text: topic?.videoUrl ?? '');
    final scrapeCtrl = TextEditingController();
    bool scraping = false;
    String scrapeStatus = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(topic == null ? 'Add Topic' : 'Edit Topic'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                const SizedBox(height: 8),
                TextField(controller: videoCtrl, decoration: const InputDecoration(labelText: 'Video URL (optional)')),
                const SizedBox(height: 8),
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(labelText: 'Content / Notes'),
                  maxLines: 6,
                ),
                const SizedBox(height: 12),
                const Divider(),
                const Text('Or scrape notes from URL:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: scrapeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'GeeksforGeeks / TutorialsPoint URL',
                    hintText: 'https://www.geeksforgeeks.org/...',
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: scraping ? null : () async {
                    if (scrapeCtrl.text.isEmpty) return;
                    setS(() { scraping = true; scrapeStatus = 'Scraping from URL...'; });
                    try {
                      final topicId = topic?.id ?? 0;
                      final scraped = await widget.db.scrapeTopicContent(
                        scrapeCtrl.text,
                        topicId: topicId,
                      );
                      if (scraped != null && scraped.isNotEmpty) {
                        contentCtrl.text = scraped;
                        setS(() { scraping = false; scrapeStatus = '✅ Content fetched from ${scrapeCtrl.text.contains('geeksforgeeks') ? 'GeeksforGeeks' : 'TutorialsPoint'} and saved!'; });
                      } else {
                        setS(() { scraping = false; scrapeStatus = '❌ Backend not running or URL unsupported. Start backend with: uvicorn main:app'; });
                      }
                    } catch (e) {
                      setS(() { scraping = false; scrapeStatus = '❌ Error: $e'; });
                    }
                  },
                  icon: scraping
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download),
                  label: const Text('Fetch Notes'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
                ),
                if (scrapeStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(scrapeStatus, style: TextStyle(
                      color: scrapeStatus.contains('✅') ? Colors.green : Colors.red,
                      fontSize: 12,
                    )),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;
                if (topic == null) {
                  // Add new topic
                  final newId = (_selectedSubjectId * 100) + _topics.length + 1;
                  await widget.db.addTopicWithData(
                    id: newId,
                    subjectId: _selectedSubjectId,
                    title: titleCtrl.text,
                    content: contentCtrl.text,
                    videoUrl: videoCtrl.text.isEmpty ? null : videoCtrl.text,
                  );
                } else {
                  await widget.db.updateTopic(
                    id: topic.id,
                    title: titleCtrl.text,
                    content: contentCtrl.text,
                    videoUrl: videoCtrl.text.isEmpty ? null : videoCtrl.text,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTopics();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTopic(dynamic topic) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Topic'),
        content: Text('Delete "${topic.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.db.deleteTopic(topic.id);
      _loadTopics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Subject selector
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Subject: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedSubjectId,
                  isExpanded: true,
                  items: _subjects.map((s) => DropdownMenuItem<int>(
                    value: s['id'] as int,
                    child: Text(s['name'] as String),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) { setState(() => _selectedSubjectId = v); _loadTopics(); }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 32),
                onPressed: () => _showAddEditDialog(),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _topics.isEmpty
                  ? const Center(child: Text('No topics. Tap + to add.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _topics.length,
                      itemBuilder: (ctx, i) {
                        final t = _topics[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                              child: Text('${i + 1}', style: const TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              t.content.isNotEmpty ? t.content.substring(0, t.content.length.clamp(0, 60)) + '...' : 'No content',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: AppColors.primaryBlue), onPressed: () => _showAddEditDialog(topic: t)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteTopic(t)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// USERS TAB
// ─────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  final FirebaseFirestoreService db;
  const _UsersTab({required this.db});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await widget.db.getAllUsers();
    setState(() { _users = users; _loading = false; });
  }

  Future<void> _toggleRole(Map<String, dynamic> user) async {
    final newRole = user['role'] == 'admin' ? 'student' : 'admin';
    await widget.db.updateUserRole(user['id'], newRole);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return const Center(child: Text('No users found.'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _users.length,
      itemBuilder: (ctx, i) {
        final u = _users[i];
        final isAdmin = u['role'] == 'admin';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isAdmin ? AppColors.primaryOrange.withOpacity(0.15) : AppColors.primaryBlue.withOpacity(0.1),
              child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: isAdmin ? AppColors.primaryOrange : AppColors.primaryBlue),
            ),
            title: Text(u['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(u['email'] ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAdmin ? AppColors.primaryOrange.withOpacity(0.15) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isAdmin ? 'Admin' : 'Student', style: TextStyle(fontSize: 11, color: isAdmin ? AppColors.primaryOrange : Colors.grey.shade700)),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _toggleRole(u),
                  child: Text(isAdmin ? 'Make Student' : 'Make Admin', style: const TextStyle(fontSize: 10, color: AppColors.primaryBlue, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// QUIZZES TAB
// ─────────────────────────────────────────────
class _QuizzesTab extends StatefulWidget {
  final FirebaseFirestoreService db;
  const _QuizzesTab({required this.db});

  @override
  State<_QuizzesTab> createState() => _QuizzesTabState();
}

class _QuizzesTabState extends State<_QuizzesTab> {
  int _selectedTopicId = 101;
  List<Map<String, dynamic>> _questions = [];
  bool _loading = true;

  final _topicNames = {
    101: 'DSA - Arrays', 102: 'DSA - Linked Lists', 103: 'DSA - Stacks',
    201: 'DBMS - Intro', 202: 'DBMS - ER Model', 301: 'OS - Intro',
    401: 'CN - Fundamentals', 501: 'Python - Basics', 601: 'Java - Basics',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final questions = await widget.db.getQuizQuestionsAdmin(_selectedTopicId);
    setState(() { _questions = questions; _loading = false; });
  }

  void _showAddDialog() {
    final qCtrl = TextEditingController();
    final aCtrl = TextEditingController();
    final bCtrl = TextEditingController();
    final cCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    String correct = 'A';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Quiz Question'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: qCtrl, decoration: const InputDecoration(labelText: 'Question'), maxLines: 3),
                const SizedBox(height: 8),
                TextField(controller: aCtrl, decoration: const InputDecoration(labelText: 'Option A')),
                TextField(controller: bCtrl, decoration: const InputDecoration(labelText: 'Option B')),
                TextField(controller: cCtrl, decoration: const InputDecoration(labelText: 'Option C')),
                TextField(controller: dCtrl, decoration: const InputDecoration(labelText: 'Option D')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: correct,
                  decoration: const InputDecoration(labelText: 'Correct Answer'),
                  items: ['A', 'B', 'C', 'D'].map((v) => DropdownMenuItem(value: v, child: Text('Option $v'))).toList(),
                  onChanged: (v) => setS(() => correct = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (qCtrl.text.isEmpty) return;
                await widget.db.addQuizQuestion(
                  topicId: _selectedTopicId,
                  question: qCtrl.text,
                  optionA: aCtrl.text,
                  optionB: bCtrl.text,
                  optionC: cCtrl.text,
                  optionD: dCtrl.text,
                  correctAnswer: correct,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Topic: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: DropdownButton<int>(
                  value: _selectedTopicId,
                  isExpanded: true,
                  items: _topicNames.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) { if (v != null) { setState(() => _selectedTopicId = v); _load(); } },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primaryGreen, size: 32),
                onPressed: _showAddDialog,
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? const Center(child: Text('No questions. Tap + to add.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _questions.length,
                      itemBuilder: (ctx, i) {
                        final q = _questions[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(radius: 12, backgroundColor: AppColors.primaryBlue, child: Text('${i+1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(q['question_text'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                      onPressed: () async {
                                        await widget.db.deleteQuizQuestion(q['id']);
                                        _load();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...['A', 'B', 'C', 'D'].map((opt) {
                                  final isCorrect = q['correct_answer'] == opt;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 4),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isCorrect ? Colors.green.shade50 : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isCorrect ? Colors.green : Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Text('$opt. ', style: TextStyle(fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.grey)),
                                        Expanded(child: Text(q['option_${opt.toLowerCase()}'] ?? '', style: TextStyle(color: isCorrect ? Colors.green.shade800 : Colors.black87))),
                                        if (isCorrect) const Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
