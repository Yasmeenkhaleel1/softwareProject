import 'package:flutter/material.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/admin_experts_page.dart';
import 'pages/admin_payments_page.dart';
import 'widgets/admin_sidebar.dart';
import 'pages/admin_earnings_page.dart';
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int selectedIndex = 0;

  final pages = const [
    AdminDashboardPage(),
    AdminExpertsPage(),
    AdminPaymentsPage(),
     AdminEarningsPage(),
  ];

 @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              title: const Text("Admin Dashboard"),
              backgroundColor: const Color(0xFF62C6D9),
            ),
      drawer: isWide ? null : Drawer(child: AdminSidebar(onSelect: _onSelect)),
      body: Row(
        children: [
          if (isWide)
            AdminSidebar(
              selectedIndex: selectedIndex,
              onSelect: _onSelect,
            ),
          Expanded(child: pages[selectedIndex]),
        ],
      ),
    );
  }

  void _onSelect(int index) {
    setState(() => selectedIndex = index);
  }
}