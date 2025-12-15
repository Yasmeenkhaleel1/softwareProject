// lib/pages/expert_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'expert_earnings_page.dart';
import 'my_availability_page.dart';

import '../widgets/stat_card.dart';
import '../config/api_config.dart';

import 'edit_expert_profile_page.dart';
import 'view_expert_profile_page.dart';
import 'my_services_page.dart';
import 'my_booking_tab.dart';
import 'notifications_page.dart';
import '../services/notifications_api.dart';
import 'chat/conversations_page.dart';
import 'expert_customers_page.dart';

class ExpertDashboardPage extends StatefulWidget {
  const ExpertDashboardPage({super.key});

  @override
  State<ExpertDashboardPage> createState() => _ExpertDashboardPageState();
}

class _ExpertDashboardPageState extends State<ExpertDashboardPage>
    with SingleTickerProviderStateMixin {
  // ========================
  // STATE
  // ========================
  int totalServices = 0;
  int totalBookings = 0;
  int totalClients = 0;

  bool _loadingMe = true;
  Map<String, dynamic>? _me;

  bool _notifOpen = false;
  bool _loadingNotifs = true;
  List<dynamic> _notifications = [];

  int _mainTabIndex = 0;
  int _mobileBottomNavIndex = 0;

  bool get _isMobile => MediaQuery.of(context).size.width < 768;
  late TabController _webTabController;

  // قائمة الأيقونات للويب
  final List<IconData> _webTabIcons = [
    Icons.dashboard,
    Icons.person,
    Icons.work,
    Icons.event,
    Icons.group,
    Icons.account_balance_wallet,
    Icons.schedule,
  ];

  // قائمة العناوين للويب
  final List<String> _webTabLabels = [
    'Overview',
    'Profile',
    'Services',
    'Bookings',
    'Customers',
    'Earnings',
    'Availability',
  ];

  // ========================
  // WEB TAB NAVIGATION
  // ========================
  void _onWebTabTapped(int index) {
    switch (index) {
      case 0:
        // Overview → نفس الصفحة
        break;
      case 1:
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const ViewExpertProfilePage()));
        break;
      case 2:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyServicesPage()));
        break;
      case 3:
        Navigator.push(
            context, MaterialPageRoute(builder: (_) => const MyBookingTab()));
        break;
      case 4:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ExpertCustomersPage()));
        break;
      case 5:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ExpertEarningsPage()));
        break;
      case 6:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyAvailabilityPage()));
        break;
    }
  }

  // ========================
  // INIT
  // ========================
  @override
  void initState() {
    super.initState();
    _webTabController = TabController(length: 7, vsync: this);
    _loadMe();
    _loadDashboardStats();
    _fetchNotifications();
  }

  @override
  void dispose() {
    _webTabController.dispose();
    super.dispose();
  }

  // ========================
  // HELPERS
  // ========================
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ========================
  // API CALLS
  // ========================
  Future<void> _loadDashboardStats() async {
    final token = await _getToken();
    try {
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/expert/dashboard"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          totalServices = data['services'] ?? 0;
          totalBookings = data['bookings'] ?? 0;
          totalClients = data['clients'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard stats: $e");
    }
  }

  Future<void> _loadMe() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/expertProfiles/me"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint("Loaded profile data: $data");
        setState(() {
          _me = data;
          _loadingMe = false;
        });
      } else {
        debugPrint("GET /me failed: ${res.statusCode}");
        setState(() => _loadingMe = false);
      }
    } catch (e) {
      debugPrint("loadMe error: $e");
      setState(() => _loadingMe = false);
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/notifications"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _notifications = data['notifications'] ?? [];
          _loadingNotifs = false;
        });
      } else {
        setState(() => _loadingNotifs = false);
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      setState(() => _loadingNotifs = false);
    }
  }

  // ========================
  // PROFILE EDIT LOGIC
  // ========================
  Future<void> _onEditProfilePressed() async {
    if (_me == null) return;

    final approved = _me!['approvedProfile'];
    final draft = _me!['draftProfile'];
    final pending = _me!['pendingProfile'];

    if (pending != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("بروفايلك تحت المراجعة حاليًا.")),
      );
      return;
    }

    if (draft != null) {
      _openEditor(draft);
      return;
    }

    if (approved != null) {
      final draftObj = await _createDraftFromApproved(approved);
      if (draftObj != null) _openEditor(draftObj);
      return;
    }

    final draftObj = await _createEmptyDraft();
    if (draftObj != null) _openEditor(draftObj);
  }

  Future<Map<String, dynamic>?> _createDraftFromApproved(
      Map<String, dynamic> approved) async {
    try {
      final token = await _getToken();
      final body = {
        "name": approved['name'],
        "bio": approved['bio'],
        "specialization": approved['specialization'],
        "experience": approved['experience'],
        "location": approved['location'],
        "profileImageUrl": approved['profileImageUrl'],
        "certificates": approved['certificates'] ?? [],
        "gallery": approved['gallery'] ?? [],
      };
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/expertProfiles/draft"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _me!['draftProfile'] = data['draft'];
        });
        return data['draft'];
      } else {
        debugPrint("Create draft failed: ${res.statusCode} ${res.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذّر إنشاء مسودة للتعديل")),
        );
      }
    } catch (e) {
      debugPrint("createDraftFromApproved err: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> _createEmptyDraft() async {
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/expertProfiles/draft"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        setState(() {
          _me!['draftProfile'] = data['draft'];
        });
        return data['draft'];
      } else {
        debugPrint("Create empty draft failed: ${res.statusCode} ${res.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("تعذّر إنشاء مسودة جديدة")),
        );
      }
    } catch (e) {
      debugPrint("createEmptyDraft err: $e");
    }
    return null;
  }

  void _openEditor(Map<String, dynamic> draft) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditExpertProfilePage(draft: draft),
      ),
    );
    _loadMe();
  }

  // ========================
  // MOBILE NAVIGATION
  // ========================
  void _onMobileBottomNavTapped(int index) {
    setState(() {
      _mobileBottomNavIndex = index;
      _mainTabIndex = index;
    });

    switch (index) {
      case 0: // Overview
        // نبقى في الصفحة الحالية
        break;
      case 1: // Profile
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ViewExpertProfilePage(),
          ),
        ).then((_) {
          setState(() {
            _mobileBottomNavIndex = 0;
            _mainTabIndex = 0;
          });
        });
        break;
      case 2: // Services
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyServicesPage(),
          ),
        ).then((_) {
          setState(() {
            _mobileBottomNavIndex = 0;
            _mainTabIndex = 0;
          });
        });
        break;
      case 3: // Bookings
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyBookingTab(),
          ),
        ).then((_) {
          setState(() {
            _mobileBottomNavIndex = 0;
            _mainTabIndex = 0;
          });
        });
        break;
      case 4: // Customers
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ExpertCustomersPage(),
          ),
        ).then((_) {
          setState(() {
            _mobileBottomNavIndex = 0;
            _mainTabIndex = 0;
          });
        });
        break;
      case 5: // Earnings
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ExpertEarningsPage(),
          ),
        ).then((_) {
          setState(() {
            _mobileBottomNavIndex = 0;
            _mainTabIndex = 0;
          });
        });
        break;
      case 6: // Availability
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const MyAvailabilityPage(),
          ),
        ).then((_) {
          setState(() {
            _mobileBottomNavIndex = 0;
            _mainTabIndex = 0;
          });
        });
        break;
    }
  }

  // ========================
  // UI BUILD
  // ========================
  @override
  Widget build(BuildContext context) {
    // ===== PREPARE PROFILE DATA =====
    String displayName = "Expert";
    String specialization = "";
    String bio = "";
    String? imageUrl;

    if (_me != null) {
      final approved = _me!['approvedProfile'];
      final pending = _me!['pendingProfile'];
      final draft = _me!['draftProfile'];
      final profile = _me!['profile'];

      displayName = approved?['name'] ??
          pending?['name'] ??
          draft?['name'] ??
          profile?['name'] ??
          "Expert";

      specialization = approved?['specialization'] ??
          pending?['specialization'] ??
          draft?['specialization'] ??
          profile?['specialization'] ??
          "";

      bio = approved?['bio'] ??
          pending?['bio'] ??
          draft?['bio'] ??
          profile?['bio'] ??
          "";

      // ✅ الحل النهائي للصورة
      String? rawImageUrl = approved?['profileImageUrl'] ??
          pending?['profileImageUrl'] ??
          draft?['profileImageUrl'] ??
          profile?['profileImageUrl'];

      imageUrl = rawImageUrl != null && rawImageUrl.isNotEmpty
          ? ApiConfig.fixAssetUrl(rawImageUrl)
          : null;

      debugPrint("Profile Image Debug:");
      debugPrint("  Raw URL: $rawImageUrl");
      debugPrint("  Fixed URL: $imageUrl");
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expert Dashboard",style: TextStyle(color: Colors.white),),
        backgroundColor: const Color(0xFF3CB8D4),

        // ✅ TabBar للويب فقط - مع أيقونات وتحسينات
        bottom: !_isMobile
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  color: const Color(0xFF3CB8D4), // لون الخلفية الأزرق
                  child: TabBar(
                    controller: _webTabController,
                     isScrollable: false, 
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.7),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    tabs: List.generate(
                      _webTabLabels.length,
                      (index) => Tab(
                        icon: Icon(
                          _webTabIcons[index],
                          size: 20,
                        ),
                        text: _webTabLabels[index],
                      ),
                    ),
                    onTap: (index) => _onWebTabTapped(index),
                  ),
                ),
              )
            : null,

        actions: [
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConversationsPage()),
              );
            },
          ),
          // 🔔 الإشعارات مع عدّاد
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _notifOpen ? Icons.notifications : Icons.notifications_none,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await NotificationsAPI.markAllAsRead();
                  setState(() => _notifOpen = !_notifOpen);
                  _fetchNotifications();
                },
              ),
              Positioned(
                right: 4,
                top: 4,
                child: FutureBuilder(
                  future: NotificationsAPI.getUnreadCount(),
                  builder: (context, snap) {
                    if (!snap.hasData || snap.data == 0) {
                      return const SizedBox();
                    }
                    return Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${snap.data}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _isMobile ? _buildMobileBottomNav() : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== PROFILE CARD =====
            _buildProfileCard(displayName, specialization, bio, imageUrl),
            const SizedBox(height: 24),

            // ===== DASHBOARD TITLE =====
            const Text(
              "Dashboard Overview",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ===== STATS GRID =====
            _buildStatsGrid(),

            // ===== QUICK ACTIONS (Mobile only) =====
            if (_isMobile) ...[
              const SizedBox(height: 24),
              _buildMobileQuickActions(),
            ],
          ],
        ),
      ),
    );
  }

  // ========================
  // PROFILE CARD
  // ========================
  Widget _buildProfileCard(
    String name,
    String specialization,
    String bio,
    String? imageUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          // Profile Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF3CB8D4).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: _loadingMe
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : (imageUrl != null && imageUrl.isNotEmpty)
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return Container(
                              color: const Color(0xFFE5F4F7),
                              child: const Center(
                                child: Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Color(0xFF3CB8D4),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: const Color(0xFFE5F4F7),
                          child: const Center(
                            child: Icon(
                              Icons.person,
                              size: 32,
                              color: Color(0xFF3CB8D4),
                            ),
                          ),
                        ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (specialization.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    specialization,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _loadingMe ? null : _onEditProfilePressed,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text("Edit Profile"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================
  // STATS GRID
  // ========================
  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount;

        if (width >= 1100) {
          crossAxisCount = 4;
        } else if (width >= 800) {
          crossAxisCount = 3;
        } else {
          // 📱 موبايل
          crossAxisCount = 2;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: _isMobile ? 0.95 : 1.25,
          children: [
            StatCard(
              title: 'Services',
              value: '$totalServices',
              icon: Icons.home_repair_service,
              color: const Color(0xFF3CB8D4),
              subtitle: 'Active services',
              trend: '+2 this week',
            ),
            StatCard(
              title: 'Clients',
              value: '$totalClients',
              icon: Icons.group,
              color: const Color(0xFF2F8CA5),
              subtitle: 'Total clients',
              trend: '+5 this month',
            ),
            StatCard(
              title: 'Bookings',
              value: '$totalBookings',
              icon: Icons.event_available,
              color: const Color(0xFF285E6E),
              subtitle: 'Active bookings',
              trend: '3 pending',
            ),
          ],
        );
      },
    );
  }

  // ========================
  // MOBILE BOTTOM NAV
  // ========================
  Widget _buildMobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: _mobileBottomNavIndex,
      onTap: _onMobileBottomNavTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF3CB8D4),
      unselectedItemColor: Colors.grey[600],
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Overview',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.work),
          label: 'Services',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Customers',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Earnings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.schedule),
          label: 'Availability',
        ),
      ],
    );
  }

  // ========================
  // MOBILE QUICK ACTIONS
  // ========================
  Widget _buildMobileQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildQuickActionButton(
              icon: Icons.add,
              label: 'New Service',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyServicesPage()),
              ),
            ),
            _buildQuickActionButton(
              icon: Icons.calendar_today,
              label: 'Schedule',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyBookingTab()),
              ),
            ),
            _buildQuickActionButton(
              icon: Icons.chat,
              label: 'Messages',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConversationsPage()),
              ),
            ),
          ],
        ),
      ],
    );
  }

Widget _buildQuickActionButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: const Color(0xFF3CB8D4),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
    }