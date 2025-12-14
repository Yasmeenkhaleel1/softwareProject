// lib/pages/signup_page.dart
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_page.dart';
import 'landing_page.dart';
import 'verify_code_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String gender = 'FEMALE';
  String role = 'CUSTOMER';
  bool loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passCtrl.text != _confirmCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final err = await AuthService().register(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        age: int.tryParse(_ageCtrl.text.trim()) ?? 18,
        gender: gender,
        role: role,
      );

      if (err == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyCodePage(email: _emailCtrl.text.trim()),
          ),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Error: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Widget _buildTextField({
    required IconData icon,
    required String label,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    required TextEditingController controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
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
                  onLogout: () async {},
                ),
              ),
            );
          },
        ),
        title: const Text(
          "Sign Up",
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
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header icon + title
                    Column(
                      children: const [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFF62C6D9),
                          child: Icon(Icons.person_add_alt_1,
                              size: 40, color: Colors.white),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Create Your Account",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 22),
                        child: Column(
                          children: [
                            _buildTextField(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v != null && v.contains('@')
                                  ? null
                                  : 'Enter a valid email',
                            ),
                            _buildTextField(
                              icon: Icons.lock_outline,
                              label: 'Password',
                              controller: _passCtrl,
                              obscure: true,
                              validator: (v) =>
                                  v != null && v.length >= 6
                                      ? null
                                      : 'Min 6 characters',
                            ),
                            _buildTextField(
                              icon: Icons.lock_outline,
                              label: 'Confirm Password',
                              controller: _confirmCtrl,
                              obscure: true,
                              validator: (v) =>
                                  v != null && v == _passCtrl.text
                                      ? null
                                      : 'Passwords do not match',
                            ),
                            _buildTextField(
                              icon: Icons.calendar_month,
                              label: 'Age',
                              controller: _ageCtrl,
                              keyboardType: TextInputType.number,
                              validator: (v) => v != null && v.isNotEmpty
                                  ? null
                                  : 'Enter your age',
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'FEMALE', child: Text('FEMALE')),
                                DropdownMenuItem(
                                    value: 'MALE', child: Text('MALE')),
                              ],
                              onChanged: (v) =>
                                  setState(() => gender = v ?? 'FEMALE'),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: role,
                              decoration: const InputDecoration(
                                labelText: 'I am a ...',
                                prefixIcon: Icon(Icons.badge),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'CUSTOMER',
                                    child: Text('CUSTOMER')),
                                DropdownMenuItem(
                                    value: 'EXPERT', child: Text('EXPERT')),
                              ],
                              onChanged: (v) =>
                                  setState(() => role = v ?? 'CUSTOMER'),
                            ),
                            const SizedBox(height: 22),
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
                                onPressed: loading ? null : _submit,
                                child: Text(
                                  loading ? 'Please wait...' : 'Sign Up',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                LoginPage(onLoginSuccess: () async {}),
                          ),
                        );
                      },
                      child: const Text(
                        "Already have an account? Log In",
                        style: TextStyle(
                          color: Color(0xFF62C6D9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
