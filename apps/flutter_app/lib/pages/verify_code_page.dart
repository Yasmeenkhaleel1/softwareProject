import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  Future<void> verifyCode() async {
    setState(() => loading = true);
    try {
      final res = await http.post(
        Uri.parse('http://localhost:5000/auth/verify-code'),
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

      if (res.statusCode == 200 && data['message'].contains('success')) {
        // ✅ التحقق ناجح → ننتقل تلقائيًا لصفحة تسجيل الدخول
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Verification successful! You can log in now."),
            backgroundColor: Colors.green,
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LoginPage(onLoginSuccess: () async {}),
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
        Uri.parse('http://localhost:5000/auth/resend-code'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFFAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text('Email Verification'),
      ),
      body: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Color(0xFF62C6D9), size: 70),
              const SizedBox(height: 10),
              Text(
                "Enter the verification code sent to\n${widget.email}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: codeCtrl,
                decoration: InputDecoration(
                  labelText: "Verification Code",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
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
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Verify",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              TextButton(
                onPressed: loading ? null : resendCode,
                child: const Text(
                  "Resend Code",
                  style: TextStyle(color: Color(0xFF007AFF)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
