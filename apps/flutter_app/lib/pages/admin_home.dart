import 'package:flutter/material.dart';
import 'admin_dashboard_page.dart';
import 'admin_expert_page.dart';
import 'admin_payments_page.dart';
import 'admin_earnings_page.dart';
import 'admin_disputes_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int selectedIndex = 0;
  final bool _drawerOpen = false;

  final pages = [
    AdminDashboardPage(),
    AdminExpertPage(expertId: ''),
    AdminPaymentsPage(),
    AdminEarningsPage(),
    const AdminDisputesPage(),
  ];

  void _onSelect(int index) {
    if (index == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Select an expert from dashboard"),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() => selectedIndex = index);
    if (_drawerOpen) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    final bool isTablet = MediaQuery.of(context).size.width < 1100;

    return isMobile 
        ? _buildMobileView(context) 
        : isTablet 
          ? _buildTabletView(context) 
          : _buildDesktopView(context);
  }

  // 📱 Mobile (شاشات صغيرة)
  Widget _buildMobileView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Panel"),
        backgroundColor: const Color(0xFF285E6E),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => _showNotification(),
          ),
        ],
      ),
      drawer: _buildDrawer(isMobile: true),
      body: pages[selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // 📱 Tablet (شاشات متوسطة)
  Widget _buildTabletView(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("LostTreasure Admin"),
        backgroundColor: const Color(0xFF285E6E),
        centerTitle: true,
      ),
      drawer: _buildDrawer(isMobile: false),
      body: pages[selectedIndex],
    );
  }

  // 🖥️ Desktop (شاشات كبيرة)
  Widget _buildDesktopView(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF62C6D9),
                        Color(0xFF347C8B),
                        Color(0xFF244C63),
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.diamond_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "LostTreasure",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildAdminInfo(),
                    ],
                  ),
                ),

                // Navigation
                Expanded(
                  child: ListView(
                    children: [
                      _buildNavItem(0, Icons.dashboard, "Dashboard"),
                      _buildNavItem(1, Icons.people, "Experts"),
                      _buildNavItem(2, Icons.payments, "Payments"),
                      _buildNavItem(3, Icons.show_chart, "Earnings"),
                      _buildNavItem(4, Icons.gavel, "Disputes"),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text("Settings"),
                        onTap: () => _showSettings(),
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text("Logout", style: TextStyle(color: Colors.red)),
                        onTap: () => _logout(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Search...",
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.notifications_none),
                        onPressed: () => _showNotification(),
                      ),
                    ],
                  ),
                ),

                // Page Content
                Expanded(child: pages[selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Shared Components
  Widget _buildDrawer({required bool isMobile}) {
    return Drawer(
      width: isMobile ? 280 : 320,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF62C6D9),
                  Color(0xFF347C8B),
                  Color(0xFF244C63),
                ],
              ),
            ),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.admin_panel_settings, size: 40, color: Color(0xFF244C63)),
                ),
                const SizedBox(height: 16),
                _buildAdminInfo(),
              ],
            ),
          ),

          // Navigation
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 20),
              children: [
                _buildDrawerItem(0, Icons.dashboard, "Dashboard"),
                _buildDrawerItem(1, Icons.people, "Experts"),
                _buildDrawerItem(2, Icons.payments, "Payments"),
                _buildDrawerItem(3, Icons.show_chart, "Earnings"),
                _buildDrawerItem(4, Icons.gavel, "Disputes"),
                const Divider(),
                _buildDrawerItem(-1, Icons.settings, "Settings"),
                _buildDrawerItem(-1, Icons.help, "Help"),
                _buildDrawerItem(-1, Icons.logout, "Logout", isLogout: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String label, {bool isLogout = false}) {
    final bool isSelected = selectedIndex == index;
    
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : (isSelected ? const Color(0xFF62C6D9) : Colors.grey.shade700)),
      title: Text(label, style: TextStyle(
        color: isLogout ? Colors.red : (isSelected ? const Color(0xFF244C63) : Colors.grey.shade700),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: isSelected,
      selectedTileColor: const Color(0xFFE8F4F8).withOpacity(0.5),
      onTap: () {
        if (isLogout) {
          _logout();
        } else if (index >= 0) {
          _onSelect(index);
        } else {
          _handleSpecialItem(label);
        }
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBottomNavItem(0, Icons.dashboard, "Dashboard"),
            _buildBottomNavItem(1, Icons.people, "Experts"),
            _buildBottomNavItem(2, Icons.payments, "Payments"),
            _buildBottomNavItem(-1, Icons.menu, "More"),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final bool isSelected = selectedIndex == index;
    final bool isMenu = index == -1;

    return GestureDetector(
      onTap: isMenu
          ? () => Scaffold.of(context).openDrawer()
          : () => _onSelect(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF62C6D9) : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF244C63) : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final bool isSelected = selectedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFE8F4F8) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isSelected ? Border.all(color: const Color(0xFF62C6D9).withOpacity(0.3)) : null,
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? const Color(0xFF62C6D9) : Colors.grey.shade600),
        title: Text(label, style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF244C63) : Colors.grey.shade700,
        )),
        onTap: () => _onSelect(index),
      ),
    );
  }

  Widget _buildAdminInfo() {
    return const Column(
      children: [
        Text(
          "Administrator",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "admin@losttreasure.com",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // 🔧 Helper Methods
  void _showNotification() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No new notifications"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Settings page")),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logged out successfully")),
              );
            },
            child: const Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleSpecialItem(String label) {
    switch (label) {
      case "Settings":
        _showSettings();
        break;
      case "Help":
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Help & Support")),
        );
        break;
    }
  }
}