import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart' as app_models;

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register with email and password
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(name);

      // Create user document in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'name': name,
        'email': email,
        'role': 'student',
        'created_at': FieldValue.serverTimestamp(),
        'total_xp': 0,
        'streak_days': 0,
        'quizzes_taken': 0,
      });

      return {
        'success': true,
        'message': 'Registration successful',
        'user': app_models.User(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          role: 'student',
        ),
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      if (e.code == 'weak-password') {
        message = 'The password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'An account already exists for this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  // Login with email and password
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Attempting login for: $email');
      
      // More aggressive cache clearing
      await _auth.signOut();
      await Future.delayed(const Duration(milliseconds: 500));
      
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Firebase auth successful for: ${userCredential.user?.uid}');

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found in Firestore');
        return {'success': false, 'message': 'User data not found'};
      }

      final userData = userDoc.data()!;
      print('📄 User data retrieved: $userData');

      final user = app_models.User(
        id: userCredential.user!.uid,
        name: userData['name'] ?? 'User',
        email: userData['email'] ?? email,
        role: userData['role'] ?? 'student',
      );
      print('✅ User object created successfully: ${user.toJson()}');

      return {
        'success': true,
        'message': 'Login successful',
        'user': user,
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled';
      }
      print('❌ Firebase auth error: $message (${e.code})');
      return {'success': false, 'message': message};
    } catch (e) {
      print('❌ Unexpected login error: $e');
      
      // Handle PigeonUserDetails type cast error specifically
      if (e.toString().contains('PigeonUserDetails')) {
        print('🔄 Detected PigeonUserDetails error, performing aggressive cache clearing...');
        
        try {
          // Very aggressive cache clearing
          for (int i = 0; i < 3; i++) {
            print('🔄 Cache clearing attempt ${i + 1}/3');
            await _auth.signOut();
            await Future.delayed(const Duration(seconds: 2));
            
            // Try to create a fresh auth instance by waiting
            await Future.delayed(const Duration(milliseconds: 500));
            
            final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
              email: email,
              password: password,
            );
            
            print('✅ Auth successful on attempt ${i + 1}');
            
            // Get user data from Firestore
            final userDoc = await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();

            if (userDoc.exists) {
              final userData = userDoc.data()!;
              final user = app_models.User(
                id: userCredential.user!.uid,
                name: userData['name'] ?? 'User',
                email: userData['email'] ?? email,
                role: userData['role'] ?? 'student',
              );
              
              print('✅ Login successful after cache clearing');
              return {
                'success': true,
                'message': 'Login successful',
                'user': user,
              };
            } else {
              print('❌ User document not found on attempt ${i + 1}');
            }
          }
          
          print('❌ All cache clearing attempts failed');
          print('🔄 Falling back to alternative login method...');
          return await loginAlternative(email: email, password: password);
          
        } catch (retryError) {
          print('❌ Aggressive retry failed: $retryError');
          return {'success': false, 'message': 'Authentication cache corruption detected. Please restart the app completely or clear app data and try again.'};
        }
      }
      
      print('Stack trace: ${StackTrace.current}');
      return {'success': false, 'message': 'An error occurred: ${e.toString()}'};
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Alternative login method to bypass PigeonUserDetails issue
  Future<Map<String, dynamic>> loginAlternative({
    required String email,
    required String password,
  }) async {
    try {
      print('🔄 Using alternative login method for: $email');
      
      // Clear cache completely
      await _auth.signOut();
      await Future.delayed(const Duration(seconds: 3));
      
      // Use credential method instead of signInWithEmailAndPassword
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final user = credential.user;
      if (user == null) {
        return {'success': false, 'message': 'Authentication failed'};
      }
      
      print('✅ Alternative auth successful for: ${user.uid}');
      
      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        print('❌ User document not found in Firestore');
        return {'success': false, 'message': 'User data not found'};
      }

      final userData = userDoc.data()!;
      print('📄 User data retrieved: $userData');

      final appUser = app_models.User(
        id: user.uid,
        name: userData['name'] ?? 'User',
        email: userData['email'] ?? email,
        role: userData['role'] ?? 'student',
      );
      print('✅ User object created successfully: ${appUser.toJson()}');

      return {
        'success': true,
        'message': 'Login successful',
        'user': appUser,
      };
      
    } catch (e) {
      print('❌ Alternative login failed: $e');
      return {'success': false, 'message': 'Alternative login failed: ${e.toString()}'};
    }
  }

  // Get user data from Firestore
  Future<app_models.User?> getUserData(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return app_models.User(
          id: uid,
          name: data['name'] ?? 'User',
          email: data['email'] ?? '',
          role: data['role'] ?? 'student',
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update user stats
  Future<void> updateUserStats({
    required String uid,
    int? xpToAdd,
    bool? incrementQuizzes,
    int? streakDays,
  }) async {
    try {
      final Map<String, dynamic> updates = {};

      if (xpToAdd != null) {
        updates['total_xp'] = FieldValue.increment(xpToAdd);
      }
      if (incrementQuizzes == true) {
        updates['quizzes_taken'] = FieldValue.increment(1);
      }
      if (streakDays != null) {
        updates['streak_days'] = streakDays;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }
}
