import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';
import 'landing_page.dart';
import 'expert_dashboard_page.dart';
import 'expert_profile_page.dart';
import 'admin_dashboard_page.dart';
import 'customer_dashboard_page.dart';
import '../services/auth_service.dart';

class InitialPage extends StatefulWidget {
  const InitialPage({super.key});

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');
    final userId = prefs.getString('userId');

    await Future.delayed(const Duration(seconds: 1)); // ⏳ مؤثر بسيط أثناء التحميل

    if (token == null || role == null) {
      // ❌ لم يسجل الدخول بعد
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginPage(onLoginSuccess: () async {}),
        ),
      );
      return;
    }

    // ✅ تم تسجيل الدخول مسبقًا
    switch (role) {
      case 'EXPERT':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ExpertProfilePage(),
          ),
        );
        break;
      case 'ADMIN':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboardPage(),
          ),
        );
        break;
      case 'CUSTOMER':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const CustomerHomePage(),
          ),
        );
        break;
      default:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginPage(onLoginSuccess: () async {}),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF62C6D9),
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
