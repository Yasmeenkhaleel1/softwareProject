// main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/dashboard_page.dart'; // 💡 New Dashboard Page
import 'models/auth_state.dart';
import 'pages/forgot_password.dart';

void main() {
  runApp(
    ChangeNotifierProvider( // 🔑 Set up state management
      create: (context) => AuthState(),
      child: const LostTreasuresApp(),
    ),
  );
}

  // lib/main.dart

// ... (بقية الكود)

class LostTreasuresApp extends StatelessWidget {
  const LostTreasuresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ... (الإعدادات) ...
      
      routes: {
        '/': (context) => const LandingPage(),
        // 🔑 التصحيح: يجب استخدام المنشئ (Constructor) مع 'const' داخل الدالة البانية
        '/login': (context) => const LoginPage(), // ✅ هذا هو الشكل الصحيح
        '/signup': (context) => const SignUpPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}