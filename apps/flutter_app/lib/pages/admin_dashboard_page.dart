import 'package:flutter/material.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF62C6D9),
      ),
      body: const Center(
        child: Text(
          "Welcome, Admin 👑",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
