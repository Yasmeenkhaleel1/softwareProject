import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'landing_page.dart';
import 'expert_profile_page.dart';
import 'admin_dashboard_page.dart';
import 'customer_profile_page.dart';

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

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();

        // ✅ نحفظ فقط المعلومات الضرورية
        await prefs.setString('token', data['token']);
        await prefs.setString('role', data['user']['role']);
        await prefs.setString('email', data['user']['email']);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Login successful!")),
        );

        await widget.onLoginSuccess();

        // ✅ التوجيه حسب الدور
        final String role = data['user']['role'];

        Widget nextPage;
        switch (role.toUpperCase()) {
          case 'EXPERT':
            nextPage = const ExpertProfilePage(); // يملأ بياناته وينتظر الموافقة
            break;
          case 'ADMIN':
            nextPage = const AdminDashboardPage(); // لوحة تحكم المدير
            break;
          case 'CUSTOMER':
            nextPage = const CustomerProfilePage(); // صفحة الزبون
            break;
          default:
            nextPage = LandingPage(
              isLoggedIn: true,
              onLogout: () async {
                await AuthService().logout();
              },
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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
                  onLogout: () async {
                    await AuthService().logout();
                  },
                ),
              ),
            );
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline,
                  size: 80, color: Color(0xFF62C6D9)),
              const SizedBox(height: 20),
              const Text(
                "Welcome Back!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF007AFF),
                ),
              ),
              const SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      icon: Icons.email_outlined,
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (v) => email = v,
                      validator: (v) =>
                          v!.isEmpty ? "Please enter your email" : null,
                    ),
                    _buildTextField(
                      icon: Icons.lock_outline,
                      label: "Password",
                      obscure: true,
                      onChanged: (v) => password = v,
                      validator: (v) =>
                          v!.isEmpty ? "Please enter your password" : null,
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isLoading ? null : loginUser,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
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
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/signup'),
                      child: const Text(
                        "Don't have an account? Sign Up",
                        style: TextStyle(color: Color(0xFF62C6D9)),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/change-password'),
                      child: const Text(
                        "Change Password",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text("Or login using",
                        style: TextStyle(color: Colors.black54)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.facebook, color: Colors.blue, size: 28),
                        SizedBox(width: 20),
                        Icon(Icons.g_mobiledata,
                            color: Colors.redAccent, size: 32),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
