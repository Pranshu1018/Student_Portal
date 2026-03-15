import 'package:flutter/material.dart';
import '../../services/firebase_firestore_service.dart';
import '../../core/constants/app_colors.dart';

class FirebaseInitScreen extends StatefulWidget {
  const FirebaseInitScreen({super.key});

  @override
  State<FirebaseInitScreen> createState() => _FirebaseInitScreenState();
}

class _FirebaseInitScreenState extends State<FirebaseInitScreen> {
  final FirebaseFirestoreService _firestoreService = FirebaseFirestoreService();
  bool _isLoading = false;
  bool _isSeedingTopics = false;
  String _message = '';

  Future<void> _initializeSampleData() async {
    setState(() { _isLoading = true; _message = 'Initializing subjects...'; });
    try {
      await _firestoreService.initializeSampleData();
      setState(() { _isLoading = false; _message = '✅ 6 subjects added to Firestore.'; });
    } catch (e) {
      setState(() { _isLoading = false; _message = '❌ Error: ${e.toString()}'; });
    }
  }

  Future<void> _seedTopics() async {
    setState(() { _isSeedingTopics = true; _message = 'Seeding topics...'; });
    try {
      await _firestoreService.seedTopics();
      setState(() { _isSeedingTopics = false; _message = '✅ 62 topics added across all 6 subjects!'; });
    } catch (e) {
      setState(() { _isSeedingTopics = false; _message = '❌ Error: ${e.toString()}'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Initialization'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cloud_upload,
              size: 80,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Initialize Firebase Database',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will add sample subjects to your Firestore database. Run this only once.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _initializeSampleData,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload),
              label: Text(_isLoading ? 'Initializing...' : 'Initialize Subjects'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSeedingTopics ? null : _seedTopics,
              icon: _isSeedingTopics
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.topic),
              label: Text(_isSeedingTopics ? 'Seeding Topics...' : 'Seed Topics (62 topics)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 24),
            if (_message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _message.contains('✅')
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _message.contains('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: _message.contains('✅')
                        ? Colors.green[800]
                        : Colors.red[800],
                  ),
                ),
              ),
            const Spacer(),
            const Text(
              'Note: Make sure you have:\n'
              '1. Enabled Authentication in Firebase Console\n'
              '2. Created Firestore Database\n'
              '3. Set up test mode rules',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
