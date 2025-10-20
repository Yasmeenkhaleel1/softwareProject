import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'landing_page.dart';

class WaitingApprovalPage extends StatelessWidget {
  const WaitingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          "Awaiting Approval",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // ✅ العودة إلى LandingPage مع الحفاظ على تسجيل الدخول
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => LandingPage(
                  isLoggedIn: true,
                  onLogout: () async {
                    await AuthService().logout();
                  },
                  userRole: 'EXPERT', // لأنه خبير غير موافَق عليه بعد
                ),
              ),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.hourglass_empty, size: 70, color: Color(0xFF62C6D9)),
              SizedBox(height: 16),
              Text(
                "Your expert profile is under review by the admin.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF1E2A38),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "You'll receive an email once it’s approved.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
