import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_state.dart';
import 'profile_page.dart'; // Already created

// 💡 Dummy pages for other roles
class SpecialistProfilePage extends StatelessWidget {
  const SpecialistProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Specialist Dashboard')),
      body: const Center(child: Text('Welcome, Specialist!', style: TextStyle(fontSize: 24))),
    );
  }
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Console')),
      body: const Center(child: Text('Welcome, Admin!', style: TextStyle(fontSize: 24))),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 👁️ Listen to the AuthState to get the role
    final authState = Provider.of<AuthState>(context);

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Check authentication status
    if (!authState.isAuthenticated || authState.userRole == null) {
      // If not authenticated, redirect to the landing page
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      });
      return const Scaffold(body: Center(child: Text('Redirecting...')));
    }

    // ➡️ Render the correct screen based on the user role
    Widget content;
    switch (authState.userRole) {
      case 'customer':
        // Using the profile page as the initial dashboard for the customer
        content = const CustomerProfilePage(); 
        break;
      case 'specialist':
        content = const SpecialistProfilePage();
        break;
      case 'admin':
        content = const AdminDashboardPage();
        break;
      default:
        // Fallback or error state
        content = const Center(child: Text('Error: Unknown User Role'));
    }

    // 💡 The actual content is wrapped in a Scaffold, but since the profile pages 
    // already have AppBars, we return the content directly.
    return content;
  }
}