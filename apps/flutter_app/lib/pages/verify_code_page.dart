// lib/pages/verify_code_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'login_page.dart';

class VerifyCodePage extends StatefulWidget {
  final String email; // نمرر الإيميل من صفحة التسجيل
  const VerifyCodePage({super.key, required this.email});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final codeCtrl = TextEditingController();
  bool loading = false;
  String message = '';

  late final String _baseUrl;

  @override
  void initState() {
    super.initState();
    _baseUrl = _resolveBaseUrl();
  }

  // 🔗 يدعم Web + Android Emulator
  String _resolveBaseUrl() {
    String raw = ApiConfig.baseUrl; // مثال: http://localhost:5000
    if (raw.contains("localhost")) {
      if (kIsWeb) {
        return raw.replaceAll("localhost", "127.0.0.1");
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        return raw.replaceAll("localhost", "10.0.2.2");
      }
    }
    return raw;
  }

  Future<void> verifyCode() async {
    if (codeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the verification code")),
      );
      return;
    }

    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/verify-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'code': codeCtrl.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);
      setState(() {
        loading = false;
        message = data['message'] ?? 'Unexpected error';
      });

      if (res.statusCode == 200 &&
          (data['message'] ?? '').toString().toLowerCase().contains('success')) {
        // ✅ التحقق ناجح → ننتقل تلقائيًا لصفحة تسجيل الدخول
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Verification successful! You can log in now."),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginPage(onLoginSuccess: _dummyLoginCb),
          ),
        );
      }
    } catch (e) {
      setState(() {
        loading = false;
        message = "⚠️ Error: $e";
      });
    }
  }

  Future<void> resendCode() async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/auth/resend-code'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email}),
      );

      final data = jsonDecode(res.body);
      setState(() {
        loading = false;
        message = data['message'] ?? 'Unexpected error';
      });
    } catch (e) {
      setState(() {
        loading = false;
        message = "⚠️ Error: $e";
      });
    }
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          'Email Verification',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 420, // 📱 موبايل: كارد وسط، 💻 ويب: كارد أنيق
              ),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon + title
                      const CircleAvatar(
                        radius: 32,
                        backgroundColor: Color(0xFF62C6D9),
                        child: Icon(Icons.verified,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Verify your email",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Enter the verification code sent to\n${widget.email}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Code field
                      TextField(
                        controller: codeCtrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          letterSpacing: 4,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          labelText: "Verification Code",
                          labelStyle:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 20),

                      // Verify button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62C6D9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Verify",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: loading ? null : resendCode,
                        child: const Text(
                          "Resend Code",
                          style: TextStyle(
                            color: Color(0xFF007AFF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                      if (message.isNotEmpty)
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// دالة فاضية بس عشان LoginPage يحتاج onLoginSuccess
Future<void> _dummyLoginCb() async {}
