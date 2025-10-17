import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_state.dart';
import './landing_page.dart';
import 'profile_page.dart'; // Already created

// 💡 Dummy pages for other roles
class SpecialistProfilePage extends StatelessWidget {
  const SpecialistProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Specialist Dashboard')),
      body: const Center(
          child: Text('Welcome, Specialist!', style: TextStyle(fontSize: 24))),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Console')),
      body: const Center(
          child: Text('Welcome, Admin!', style: TextStyle(fontSize: 24))),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);

    if (!authState.isAuthenticated || authState.userRole == null) {
      return const Scaffold(
        body: Center(child: Text('Error: Not logged in')),
      );
    }

    // Decide which page to show based on user role
    switch (authState.userRole) {
      case 'customer':
        return LandingPage();
      case 'specialist':
        return const SpecialistProfilePage();
      case 'admin':
        return const AdminDashboardPage();
      default:
        return const Scaffold(
          body: Center(child: Text('Error: Unknown role')),
        );
    }
  }
}
