import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ✅ الصفحات
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/signup_page.dart';
import 'pages/change_password_page.dart';
import 'pages/expert_profile_page.dart';
import 'pages/expert_dashboard_page.dart';
import 'pages/waiting_approval_page.dart';
import 'pages/expert_profile_view.dart';
import 'pages/verify_code_page.dart';
import 'pages/customer_profile_page.dart';
import 'pages/customer_dashboard_page.dart';
import 'pages/admin_dashboard_page.dart';
import 'services/auth_service.dart';

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
  bool _isApproved = true;
  bool _hasProfile = true; // ✅ جديد

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // ✅ التحقق من حالة تسجيل الدخول + حالة الموافقة + هل الخبير أنشأ ملفه؟
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    if (token != null && role != null) {
      bool approved = true;
      bool hasProfile = true;

      if (role == 'EXPERT') {
        try {
          final res = await http.get(
            Uri.parse('http://localhost:5000/api/me'),
            headers: {'Authorization': 'Bearer $token'},
          );

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            approved = data['user']['isApproved'] == true;
            hasProfile = data['user']['hasProfile'] == true;
          } else {
            approved = false;
            hasProfile = false;
          }
        } catch (e) {
          approved = false;
          hasProfile = false;
        }
      }

      setState(() {
        _isLoggedIn = true;
        _role = role;
        _isApproved = approved;
        _hasProfile = hasProfile;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoggedIn = false;
        _role = null;
        _isApproved = true;
        _hasProfile = true;
        _isLoading = false;
      });
    }
  }

  // ✅ تسجيل الخروج
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    setState(() {
      _isLoggedIn = false;
      _role = null;
      _isApproved = true;
      _hasProfile = true;
    });
  }

  // ✅ تحديد الصفحة الرئيسية بناءً على الدور وحالة الموافقة والبروفايل
  Widget _getHomePage() {
    if (!_isLoggedIn) {
      return LandingPage(
        isLoggedIn: false,
        onLogout: _logout,
      );
    }

    switch (_role) {
      case 'EXPERT':
        if (!_hasProfile) {
          // 🟡 خبير جديد → يملأ بروفايله أولاً
          return const ExpertProfilePage();
        } else if (!_isApproved) {
          // 🟠 عنده بروفايل ولكن ينتظر موافقة الأدمن
          return const WaitingApprovalPage();
        } else {
          // 🟢 خبير موافَق عليه
          return LandingPage(
            isLoggedIn: true,
            onLogout: _logout,
            userRole: _role,
          );
        }

      case 'CUSTOMER':
        return LandingPage(
          isLoggedIn: true,
          onLogout: _logout,
          userRole: _role,
        );

      case 'ADMIN':
        return const AdminDashboardPage();

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
        '/login_page': (context) => LoginPage(
              onLoginSuccess: () async {
                await _checkLoginStatus();
              },
            ),
        '/signup_page': (context) => const SignupPage(),
        '/landing_page': (context) => LandingPage(
              isLoggedIn: _isLoggedIn,
              onLogout: _logout,
              userRole: _role,
            ),
        '/change-password': (context) => const ChangePasswordPage(),
        '/expert_profile': (context) => const ExpertProfilePage(),
        '/waiting_approval': (_) => const WaitingApprovalPage(),
        '/expert_dashboard': (context) => const ExpertDashboardPage(),
        '/expert_profile_view': (context) => const ExpertProfileViewPage(),
        '/verify-code': (context) => const VerifyCodePage(email: ''),
        '/customer_home_page': (context) =>  CustomerHomePage(),
        '/customer_profile': (context) => const CustomerProfilePage(),
        '/admin_dashboard': (context) => const AdminDashboardPage(),
      },
    );
  }
}
