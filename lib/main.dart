import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/constants/app_colors.dart';
import 'screens/auth/modern_login_screen.dart';
import 'screens/home/modern_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🔄 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully!');
    print('📱 Project: ${DefaultFirebaseOptions.currentPlatform.projectId}');
    print('🔑 App ID: ${DefaultFirebaseOptions.currentPlatform.appId}');
  } catch (e, stackTrace) {
    print('❌ Firebase initialization error: $e');
    print('Stack trace: $stackTrace');
  }
  
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Student Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.backgroundLight,
      ),
      home: const ModernLoginScreen(),
      routes: {
        '/login': (_) => const ModernLoginScreen(),
        '/home': (_) => ModernHomeScreen(),
      },
    );
  }
}
