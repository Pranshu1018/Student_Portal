import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Duolingo-inspired vibrant theme
  static const Color primaryGreen = Color(0xFF58CC02);  // Duolingo green
  static const Color primaryBlue = Color(0xFF1CB0F6);   // Bright blue
  static const Color primaryPurple = Color(0xFF9D4EDD); // Purple accent
  static const Color primaryOrange = Color(0xFFFF9600); // Orange accent
  
  // Background Colors
  static const Color backgroundLight = Color(0xFFF7F7F7);
  static const Color backgroundDark = Color(0xFF1A1A2E);
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF16213E);
  
  // Text Colors
  static const Color textPrimary = Color(0xFF3C3C3C);
  static const Color textSecondary = Color(0xFF777777);
  static const Color textLight = Colors.white;
  
  // Status Colors
  static const Color success = Color(0xFF58CC02);  // Green
  static const Color error = Color(0xFFFF4B4B);    // Red
  static const Color warning = Color(0xFFFFC800);  // Yellow
  static const Color info = Color(0xFF1CB0F6);     // Blue
  
  // Streak & Gamification
  static const Color streakFire = Color(0xFFFF9600);
  static const Color goldStar = Color(0xFFFFC800);
  static const Color silverStar = Color(0xFFC0C0C0);
  static const Color bronzeStar = Color(0xFFCD7F32);
  
  // Gradients - Duolingo style
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF58CC02), Color(0xFF3FAF00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF1CB0F6), Color(0xFF1899D6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF9D4EDD), Color(0xFF7B2CBF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [Color(0xFFFF9600), Color(0xFFFF7A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Subject-specific colors
  static const Color dsaColor = Color(0xFF1CB0F6);      // Blue
  static const Color dbmsColor = Color(0xFF9D4EDD);     // Purple
  static const Color osColor = Color(0xFFFF9600);       // Orange
  static const Color cnColor = Color(0xFF58CC02);       // Green
  static const Color pythonColor = Color(0xFF3776AB);   // Python blue
  static const Color javaColor = Color(0xFFED8B00);     // Java orange
}

