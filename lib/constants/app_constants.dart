import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C63FF);  // Vibrant Purple
  static const secondary = Color(0xFFFF4081); // Electric Pink
  static const background = Color(0xFF1F2937); // Dark Blue
  static const surface = Color(0xFF121212);   // Charcoal Black
  static const accent = Color(0xFF00D8FF);    // Bright Cyan
  static const success = Color(0xFF32FF7E);   // Neon Green
  static const warning = Color(0xFFFFC107);   // Amber Yellow
  static const text = Color(0xFFFFFFFF);      // White
  static const textSecondary = Color(0xFF9CA3AF); // Cool Gray

  static final primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primary,
      primary.withOpacity(0.8),
      background,
    ],
  );

  static final accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      accent,
      secondary,
    ],
  );
}

class AppStrings {
  static const String appName = 'Hotel Stream';
  static const List<String> welcomeMessages = [
    'Welcome to our Hotel',
    'Bienvenue à notre Hôtel',
    'Bienvenido a nuestro Hotel',
    'مرحباً بكم في فندقنا',
  ];
}
