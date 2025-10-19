import 'package:flutter/material.dart';
import 'login_page.dart';

class VerifiedScreen extends StatefulWidget {
  final bool ok;
  const VerifiedScreen({super.key, required this.ok});

  @override
  State<VerifiedScreen> createState() => _VerifiedScreenState();
}

class _VerifiedScreenState extends State<VerifiedScreen> {
  @override
  void initState() {
    super.initState();

    // ✅ انتقال تلقائي بعد ثانيتين إذا التفعيل ناجح
    if (widget.ok) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => LoginPage(
                onLoginSuccess: () async {},
              ),
            ),
          );
        }
      });
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginPage(
          onLoginSuccess: () async {},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.ok;
    return Scaffold(
      backgroundColor: success ? Colors.green.shade50 : Colors.red.shade50,
      appBar: AppBar(
        title: const Text('Email Verification'),
        backgroundColor: success ? Colors.green : Colors.red,
        automaticallyImplyLeading: false, // 🔹 منع زر الرجوع
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                success ? Icons.check_circle : Icons.error,
                color: success ? Colors.green : Colors.red,
                size: 100,
              ),
              const SizedBox(height: 20),
              Text(
                success
                    ? '✅ Verification successful!\nYou can log in now.'
                    : '❌ Verification failed.\nPlease try again or contact support.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color:
                      success ? Colors.green.shade800 : Colors.red.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 25),

              // 🔹 في حالة النجاح فقط، يظهر تنبيه أنه سيتم التحويل تلقائيًا
              if (success)
                const Text(
                  'Redirecting to login page...',
                  style: TextStyle(color: Colors.black54, fontSize: 14),
                ),

              const SizedBox(height: 30),

              // 🔹 زر الانتقال اليدوي
              ElevatedButton.icon(
                onPressed: _goToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      success ? Colors.green : Colors.redAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.login, color: Colors.white),
                label: const Text(
                  "Go to Login",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
