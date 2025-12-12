import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart'; 
class LandingPage extends StatefulWidget {
  final bool isLoggedIn;
  final void Function() onLogout;
  final String? userRole;
  final String? userId;

  const LandingPage({
    super.key,
    required this.isLoggedIn,
    required this.onLogout,
    this.userRole,
    this.userId,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
 static String get baseUrl => ApiConfig.baseUrl;


  bool loading = false;
  String? role;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUserRole();
    }
  }

  // ✅ جلب الدور الحقيقي من السيرفر
  Future<void> _fetchUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => role = data['user']['role']);
      }
    } catch (e) {
      print('❌ Error fetching role: $e');
    }
  }

  void _showSnack(String msg, {Color color = Colors.orangeAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  // ✅ انتقال الأدمن للوحة التحكم
  void _handleAdminDashboard() {
    Navigator.pushNamed(context, '/admin_dashboard_page');
  }

  // ✅ فحص موافقة الأدمن للخبير عند الضغط على Dashboard
  Future<void> _handleExpertDashboard() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final approved = data['user']['isApproved'] == true;

        if (approved) {
          Navigator.pushNamed(context, '/expert_dashboard_page');
        } else {
          _showSnack('⏳ Your profile is still under review by the admin.');
        }
      } else {
        _showSnack('❌ Failed to fetch your status.');
      }
    } catch (e) {
      _showSnack('⚠️ Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ✅ تسجيل الخروج مع تنظيف التوكن + رجوع للاندنغ
 Future<void> _handleLogout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('token');

  setState(() {
    loading = false;
    role = null;
  });

  widget.onLogout();

  if (context.mounted) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/landing_page', // ✅ نفس الاسم المسجّل في main.dart
      (Route<dynamic> route) => false,
    );
  }
}


  @override
  Widget build(BuildContext context) {
    // ✅ أثناء تحميل الدور من السيرفر
    if (widget.isLoggedIn && role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ نحدد Web / Mobile حسب عرض الشاشة
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return _LandingWebLayout(
            isLoggedIn: widget.isLoggedIn,
            role: role,
            loading: loading,
            onLogout: _handleLogout,
            onLogin: () => Navigator.pushNamed(context, '/login_page'),
            onSignup: () => Navigator.pushNamed(context, '/signup_page'),
            onCustomerDashboard: () =>
                Navigator.pushNamed(context, '/customer_dashboard_page'),
            onExpertDashboard: _handleExpertDashboard,
            onAdminDashboard: _handleAdminDashboard,
          );
        } else {
          return _LandingMobileLayout(
            isLoggedIn: widget.isLoggedIn,
            role: role,
            loading: loading,
            onLogout: _handleLogout,
            onLogin: () => Navigator.pushNamed(context, '/login_page'),
            onSignup: () => Navigator.pushNamed(context, '/signup_page'),
            onCustomerDashboard: () =>
                Navigator.pushNamed(context, '/customer_dashboard_page'),
            onExpertDashboard: _handleExpertDashboard,
            onAdminDashboard: _handleAdminDashboard,
          );
        }
      },
    );
  }
}

/// ===============================
/// 🌐 نسخة الويب
/// ===============================
class _LandingWebLayout extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final bool loading;
  final VoidCallback onLogout;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onCustomerDashboard;
  final VoidCallback onExpertDashboard;
  final VoidCallback onAdminDashboard;

  const _LandingWebLayout({
    required this.isLoggedIn,
    required this.role,
    required this.loading,
    required this.onLogout,
    required this.onLogin,
    required this.onSignup,
    required this.onCustomerDashboard,
    required this.onExpertDashboard,
    required this.onAdminDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/treasure_icon.png', height: 30),
            const SizedBox(width: 8),
            const Text(
              "LOST TREASURES",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              "Home",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "About",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "Contact Us",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (isLoggedIn)
            TextButton(
              onPressed: onLogout,
              child: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onLogin,
              child: const Text(
                "Login",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 20),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // النصوص والأزرار (اليسار)
                    Expanded(
                      flex: 1,
                      child: _LandingMainTextAndButtons(
                        isLoggedIn: isLoggedIn,
                        role: role,
                        onSignup: onSignup,
                        onLogin: onLogin,
                        onCustomerDashboard: onCustomerDashboard,
                        onExpertDashboard: onExpertDashboard,
                        onAdminDashboard: onAdminDashboard,
                        onLogout: onLogout,
                      ),
                    ),
                    const SizedBox(width: 50),
                    // الصورة (اليمين)
                    const Expanded(
                      flex: 1,
                      child: _LandingImage(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// ===============================
/// 📱 نسخة الموبايل
/// ===============================
class _LandingMobileLayout extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final bool loading;
  final VoidCallback onLogout;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onCustomerDashboard;
  final VoidCallback onExpertDashboard;
  final VoidCallback onAdminDashboard;

  const _LandingMobileLayout({
    required this.isLoggedIn,
    required this.role,
    required this.loading,
    required this.onLogout,
    required this.onLogin,
    required this.onSignup,
    required this.onCustomerDashboard,
    required this.onExpertDashboard,
    required this.onAdminDashboard,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/treasure_icon.png', height: 26),
            const SizedBox(width: 6),
            const Text(
              "LOST TREASURES",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          if (isLoggedIn)
            TextButton(
              onPressed: onLogout,
              child: const Text(
                "Logout",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            TextButton(
              onPressed: onLogin,
              child: const Text(
                "Login",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // النصوص والأزرار
                  _LandingMainTextAndButtons(
                    isLoggedIn: isLoggedIn,
                    role: role,
                    onSignup: onSignup,
                    onLogin: onLogin,
                    onCustomerDashboard: onCustomerDashboard,
                    onExpertDashboard: onExpertDashboard,
                    onAdminDashboard: onAdminDashboard,
                    onLogout: onLogout,
                    isMobile: true,
                  ),
                  const SizedBox(height: 24),
                  const _LandingImage(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}

/// ===============================
/// 🔹 Widgets مشتركة
/// ===============================

class _LandingMainTextAndButtons extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final bool isMobile;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onCustomerDashboard;
  final VoidCallback onExpertDashboard;
  final VoidCallback onAdminDashboard;
  final VoidCallback onLogout;

  const _LandingMainTextAndButtons({
    required this.isLoggedIn,
    required this.role,
    required this.onSignup,
    required this.onLogin,
    required this.onCustomerDashboard,
    required this.onExpertDashboard,
    required this.onAdminDashboard,
    required this.onLogout,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment:
          isMobile ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DISCOVER THE HIDDEN HUMAN TREASURES AROUND YOU",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2A38),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Connecting skilled and experienced individuals with those who seek their expertise.",
          style: TextStyle(
            fontSize: 16,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!isLoggedIn) ...[
              _LandingButton(
                label: "Sign Up",
                color: const Color(0xFF62C6D9),
                onPressed: onSignup,
              ),
              _LandingButton(
                label: "Log In",
                color: const Color(0xFF62C6D9),
                onPressed: onLogin,
              ),
            ] else if (role == "EXPERT") ...[
              _LandingButton(
                label: "Expert Dashboard",
                color: Colors.green,
                onPressed: onExpertDashboard,
              ),
              _LandingButton(
                label: "Logout",
                color: Colors.redAccent,
                onPressed: onLogout,
              ),
            ] else if (role == "CUSTOMER") ...[
              _LandingButton(
                label: "Customer Dashboard",
                color: const Color(0xFF62C6D9),
                onPressed: onCustomerDashboard,
              ),
              _LandingButton(
                label: "Logout",
                color: Colors.redAccent,
                onPressed: onLogout,
              ),
            ] else if (role == "ADMIN") ...[
              _LandingButton(
                label: "Admin Dashboard",
                color: Colors.orangeAccent,
                onPressed: onAdminDashboard,
              ),
              _LandingButton(
                label: "Logout",
                color: Colors.redAccent,
                onPressed: onLogout,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LandingImage extends StatelessWidget {
  const _LandingImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF62C6D9).withOpacity(0.5),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Image.asset(
          'assets/images/landing1.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _LandingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _LandingButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}