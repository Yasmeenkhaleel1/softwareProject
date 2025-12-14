// lib/pages/login_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

// ✅ استيراد الصفحات
import 'landing_page.dart';
import 'expert_profile_page.dart';
import 'waiting_approval_page.dart';

class LoginPage extends StatefulWidget {
  final Future<void> Function() onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  String email = "";
  String password = "";
  bool isLoading = false;

  late final String _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = _resolveBaseUrl();
  }

  // 🔗 نفس فكرة ApiConfig في باقي الصفحات (يدعم Web + Android Emulator)
  String _resolveBaseUrl() {
    String raw = ApiConfig.baseUrl; // مثال: http://localhost:5000
    if (raw.contains('localhost')) {
      if (kIsWeb) {
        return raw.replaceAll('localhost', '127.0.0.1');
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return raw.replaceAll('localhost', '10.0.2.2');
      }
    }
    return raw;
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email.trim(), "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();

        // ✅ حفظ المعلومات
        await prefs.setString('token', data['token']);
        await prefs.setString('role', data['user']['role']);
        await prefs.setString('email', data['user']['email']);
        await prefs.setString('userId', data['user']['id']);

        // 🔔 تسجيل FCM token
        await PushNotificationService.initFCM();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Login successful!")),
        );

        await widget.onLoginSuccess();

        final String role = data['user']['role'].toUpperCase();
        Widget nextPage;

        if (role == 'ADMIN') {
          nextPage = LandingPage(
            isLoggedIn: true,
            onLogout: () async => await AuthService().logout(),
            userRole: role,
          );
        } else if (role == 'CUSTOMER') {
          nextPage = LandingPage(
            isLoggedIn: true,
            onLogout: () async => await AuthService().logout(),
            userRole: role,
          );
        } else if (role == 'EXPERT') {
          final res = await http.get(
            Uri.parse('$_baseUrl/api/me'),
            headers: {'Authorization': 'Bearer ${data['token']}'},
          );

          if (res.statusCode == 200) {
            final info = jsonDecode(res.body);
            final approved = info['user']['isApproved'] == true;
            final hasProfile = info['user']['hasProfile'] == true;

            if (!hasProfile) {
              nextPage = const ExpertProfilePage();
            } else if (!approved) {
              nextPage = const WaitingApprovalPage();
            } else {
              nextPage = LandingPage(
                isLoggedIn: true,
                onLogout: () async => await AuthService().logout(),
                userRole: role,
              );
            }
          } else {
            nextPage = const WaitingApprovalPage();
          }
        } else {
          nextPage = LandingPage(
            isLoggedIn: true,
            onLogout: () async => await AuthService().logout(),
            userRole: role,
          );
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => nextPage),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "❌ Login failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildTextField({
    required IconData icon,
    required String label,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        obscureText: obscure,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey[700]),
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LandingPage(
                  isLoggedIn: false,
                  onLogout: () async => await AuthService().logout(),
                ),
              ),
            );
          },
        ),
        title: const Text(
          "Login",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // ✅ الويب يكون كارد عريض، الموبايل بعرض أصغر
                maxWidth: kIsWeb ? 480 : 380,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header icon + title
                  Container(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: const [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFF62C6D9),
                          child: Icon(Icons.lock_outline,
                              size: 40, color: Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Welcome Back!",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Card form
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              icon: Icons.email_outlined,
                              label: "Email",
                              keyboardType: TextInputType.emailAddress,
                              onChanged: (v) => email = v,
                              validator: (v) => v == null || v.isEmpty
                                  ? "Please enter your email"
                                  : null,
                            ),
                            _buildTextField(
                              icon: Icons.lock_outline,
                              label: "Password",
                              obscure: true,
                              onChanged: (v) => password = v,
                              validator: (v) => v == null || v.isEmpty
                                  ? "Please enter your password"
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF62C6D9),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                onPressed: isLoading ? null : loginUser,
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Login",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/signup_page'),
                    child: const Text(
                      "Don't have an account? Sign Up",
                      style: TextStyle(
                          color: Color(0xFF62C6D9),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(
                        context, '/change_password_page'),
                    child: const Text(
                      "Change Password",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
