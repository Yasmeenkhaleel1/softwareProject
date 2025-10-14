import 'package:flutter/material.dart';
import '../api/api_service.dart';
import 'login_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  bool loading = false;

  void _changePassword() async {
    setState(() => loading = true);
    final res = await ApiService.changePassword(oldCtrl.text, newCtrl.text);
    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(res['message'] ?? 'Error')),
    );

    if (res['message'] == "Password changed successfully") {
      await ApiService.logout();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) =>  LoginPage(onLoginSuccess: () {  },)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown.shade50,
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(controller: oldCtrl, decoration: const InputDecoration(labelText: "Old Password"), obscureText: true),
            TextField(controller: newCtrl, decoration: const InputDecoration(labelText: "New Password"), obscureText: true),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: loading ? null : _changePassword,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
              child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text("Change Password"),
            )
          ],
        ),
      ),
    );
  }
}
