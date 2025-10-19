import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// الصفحات
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/change_password_page.dart';
import 'pages/expert_profile_page.dart';
import 'pages/expert_dashboard.dart';
import 'pages/waiting_approval_page.dart';
import 'pages/expert_profile_view.dart';
import 'pages/verify_code_page.dart';
import 'pages/customer_profile_page.dart';
import 'pages/admin_dashboard_page.dart';

void main() {
  runApp(const LostTreasuresApp());
}

class LostTreasuresApp extends StatefulWidget {
  const LostTreasuresApp({super.key});

  @override
  State<LostTreasuresApp> createState() => _LostTreasuresAppState();
}

class _LostTreasuresAppState extends State<LostTreasuresApp> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _role;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // ✅ التحقق من حالة تسجيل الدخول بناءً على وجود التوكن فقط
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    setState(() {
      _isLoggedIn = token != null;
      _role = role;
      _isLoading = false;
    });
  }

  // ✅ تسجيل الخروج
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _isLoggedIn = false;
      _role = null;
    });
  }

  // ✅ تحديد الصفحة الرئيسية بناءً على الدور
  Widget _getHomePage() {
    if (!_isLoggedIn) {
      return LandingPage(
        isLoggedIn: false,
        onLogout: _logout,
      );
    }

    switch (_role) {
      case 'EXPERT':
        return const ExpertProfilePage(); // صفحة إنشاء أو تعديل الملف المهني
      case 'CUSTOMER':
        return const CustomerProfilePage();// صفحة المستخدم العادي
      case 'ADMIN':
        return const AdminDashboardPage(); // لوحة تحكم الأدمن
      default:
        return LandingPage(
          isLoggedIn: _isLoggedIn,
          onLogout: _logout,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lost Treasures',
      theme: ThemeData(
        primaryColor: const Color(0xFF62C6D9),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF62C6D9),
          secondary: const Color(0xFF62C6D9),
        ),
      ),
      home: _getHomePage(),
      routes: {
        '/login': (context) => LoginPage(
              onLoginSuccess: () async {
                await _checkLoginStatus();
              },
            ),
        '/signup': (context) => const SignupPage(),
        '/landing': (context) => LandingPage(
              isLoggedIn: _isLoggedIn,
              onLogout: _logout,
            ),
        '/change-password': (context) => const ChangePasswordPage(),
        '/expert_profile': (context) => const ExpertProfilePage(),
        '/waiting_approval': (_) => const WaitingApprovalPage(),
        '/expert_dashboard': (context) => const ExpertDashboardPage(),
        // ✅ إزالة userId الثابت هنا لأنه لم يعد مطلوب
        '/expert_profile_view': (context) => const ExpertProfileViewPage(),
        '/verify-code': (context) => const VerifyCodePage(email: ''),
        '/customer_profile_bage': (context) => const CustomerProfilePage(),
        '/admin_dashboard': (context) => const AdminDashboardPage(),
      },
    );
  }
}
