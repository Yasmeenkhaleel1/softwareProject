import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_appbar.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();

  String name = "";
  String email = "";
  String password = "";
  String confirmPassword = "";
  String gender = "";
  int? age;
  String role = "student"; // default

  bool isLoading = false;

  Future<void> signupUser() async {
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "name": name.trim(),
          "email": email.trim(),
          "password": password.trim(),
          "age": age,
          "gender": gender.trim(),
          "role": role
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // ✅ Save JWT token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Signup successful!")),
        );

        // ✅ Navigate to home (or login)
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Signup failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void handleMenuSelection(String value) {
    switch (value) {
      case 'login':
        Navigator.pushNamed(context, '/login');
        break;
      case 'signup':
        Navigator.pushNamed(context, '/signup');
        break;
      case 'home':
        Navigator.pushNamed(context, '/');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6E9),
      appBar: CustomAppBar(
        isLoggedIn: false,
        onMenuSelected: handleMenuSelection,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Create Account",
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007AFF)),
              ),
              const SizedBox(height: 25),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(
                      icon: Icons.person_outline,
                      label: "Full Name",
                      onChanged: (v) => name = v,
                      validator: (v) =>
                          v!.isEmpty ? "Please enter your full name" : null,
                    ),
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
                      validator: (v) => v!.length < 6
                          ? "Password must be at least 6 characters"
                          : null,
                    ),
                    _buildTextField(
                      icon: Icons.lock_outline,
                      label: "Confirm Password",
                      obscure: true,
                      onChanged: (v) => confirmPassword = v,
                      validator: (v) =>
                          v!.isEmpty ? "Please confirm your password" : null,
                    ),
                    _buildTextField(
                      icon: Icons.person,
                      label: "Gender (Optional)",
                      onChanged: (v) => gender = v,
                    ),
                    _buildTextField(
                      icon: Icons.cake_outlined,
                      label: "Age (Optional)",
                      keyboardType: TextInputType.number,
                      onChanged: (v) => age = int.tryParse(v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: InputDecoration(
                        labelText: "Role",
                        prefixIcon:
                            const Icon(Icons.work_outline, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: "student", child: Text("Customer")),
                        DropdownMenuItem(
                            value: "service_center", child: Text("Specialist")),
                        DropdownMenuItem(value: "admin", child: Text("Admin")),
                      ],
                      onChanged: (v) => setState(() => role = v!),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007AFF),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isLoading
                            ? null
                            : () {
                                if (_formKey.currentState!.validate()) {
                                  signupUser();
                                }
                              },
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Sign Up",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        "Already have an account? Log In",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Or sign up using",
                      style: TextStyle(color: Colors.black54),
                    ),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: onChanged,
        validator: validator,
      ),
    );
  }
}
