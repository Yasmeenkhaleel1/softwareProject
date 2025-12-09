// lib/pages/expert_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/stat_card.dart';
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

class _ExpertDashboardPageState extends State<ExpertDashboardPage> {
  static const baseUrl = "http://localhost:5000";

  int totalServices = 0;
  int totalBookings = 0;
  int totalClients = 0;

  bool _loadingMe = true;
  Map<String, dynamic>? _me;

  bool _notifOpen = false;
  bool _loadingNotifs = true;
  List<dynamic> _notifications = [];

  // 0 = Overview | 1 = Profile | 2 = Services | 3 = Bookings | 4 = Customers
  int _mainTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _fetchNotifications();
    _loadDashboardStats();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadDashboardStats() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse("$baseUrl/api/expert/dashboard"),
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
  }

  Future<void> _loadMe() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse("$baseUrl/api/expertProfiles/me"),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() {
          _me = jsonDecode(res.body);
          _loadingMe = false;
        });
      } else {
        debugPrint("GET /me failed: ${res.statusCode} ${res.body}");
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
        Uri.parse("$baseUrl/api/notifications"),
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
      debugPrint("❌ Error fetching notifications: $e");
      setState(() => _loadingNotifs = false);
    }
  }

  // =========================
  //  Edit Profile logic
  // =========================
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
        Uri.parse("$baseUrl/api/expertProfiles/draft"),
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
        debugPrint(
            "Create draft from approved failed: ${res.statusCode} ${res.body}");
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
        Uri.parse("$baseUrl/api/expertProfiles/draft"),
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

  // =========================
  //         UI
  // =========================
  @override
  Widget build(BuildContext context) {
    // AppBar موحّد لكل المقاسات (بدون Sidebar)
    final appBar = AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF3CB8D4),
      titleSpacing: 24,
      title: Row(
        children: const [
          Icon(Icons.auto_awesome, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Expert Workspace',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        // 💬 أيقونة المسجات
        IconButton(
          tooltip: "Messages",
          icon: const Icon(Icons.message_outlined, color: Colors.white),
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
              icon: const Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () async {
                await NotificationsAPI.markAllAsRead();
                setState(() => _notifOpen = !_notifOpen);
                _fetchNotifications();
              },
            ),
            Positioned(
              right: 6,
              top: 6,
              child: FutureBuilder(
                future: NotificationsAPI.getUnreadCount(),
                builder: (context, snap) {
                  if (!snap.hasData || snap.data == 0) {
                    return const SizedBox();
                  }
                  return Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${snap.data}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );

    // ====== تجهيز بيانات البروفايل ======
    String displayName = "Unknown Expert";
    String specialization = "";
    String bio = "";
    String? imageUrl;

    if (_me != null) {
      final user = _me!['user'] ?? {};
      final approved = _me!['approvedProfile'];
      final pending = _me!['pendingProfile'];
      final draft = _me!['draftProfile'];
      final profile = _me!['profile'];

      displayName = (approved?['name'] ??
              pending?['name'] ??
              draft?['name'] ??
              profile?['name'] ??
              user['name'] ??
              "Unknown Expert")
          as String;

      specialization = (approved?['specialization'] ??
          pending?['specialization'] ??
          draft?['specialization'] ??
          profile?['specialization'] ??
          "") as String;

      bio = (approved?['bio'] ??
          pending?['bio'] ??
          draft?['bio'] ??
          profile?['bio'] ??
          "") as String;

      imageUrl = (approved?['profileImageUrl'] ??
          pending?['profileImageUrl'] ??
          draft?['profileImageUrl'] ??
          profile?['profileImageUrl']) as String?;
    }

    final maxWidth = MediaQuery.of(context).size.width > 1200
        ? 1100.0
        : MediaQuery.of(context).size.width * 0.95;

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
          // 🌈 خلفية SaaS ناعمة
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF4F8FC),
                  Color(0xFFE5F4F7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== بطاقة البروفايل =====
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFFFFFF),
                            Color(0xFFEAF9FC),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFD7E3EE),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundImage: (imageUrl != null &&
                                    imageUrl!.startsWith("http"))
                                ? NetworkImage(imageUrl!)
                                : const AssetImage('assets/images/experts.png')
                                    as ImageProvider,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _loadingMe
                                ? const LinearProgressIndicator(minHeight: 2)
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (specialization.isNotEmpty)
                                        Text(
                                          specialization,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      if (bio.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          bio,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                          const SizedBox(width: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF3CB8D4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            onPressed:
                                _loadingMe ? null : _onEditProfilePressed,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text(
                              'Edit Profile',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== شريط تنقل رئيسي (نقلنا تبويبات الـ Sidebar هنا) =====
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFE0E7F1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          _MainNavButton(
                            title: "Overview",
                            icon: Icons.insights_outlined,
                            isActive: _mainTabIndex == 0,
                            onTap: () {
                              setState(() => _mainTabIndex = 0);
                            },
                          ),
                          _MainNavButton(
                            title: "Profile",
                            icon: Icons.person_outline,
                            isActive: _mainTabIndex == 1,
                            onTap: () {
                              setState(() => _mainTabIndex = 1);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ViewExpertProfilePage(),
                                ),
                              ).then((_) {
                                setState(() => _mainTabIndex = 0);
                              });
                            },
                          ),
                          _MainNavButton(
                            title: "Services",
                            icon: Icons.home_repair_service_outlined,
                            isActive: _mainTabIndex == 2,
                            onTap: () {
                              setState(() => _mainTabIndex = 2);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyServicesPage(),
                                ),
                              ).then((_) {
                                setState(() => _mainTabIndex = 0);
                              });
                            },
                          ),
                          _MainNavButton(
                            title: "Bookings",
                            icon: Icons.event_available_outlined,
                            isActive: _mainTabIndex == 3,
                            onTap: () {
                              setState(() => _mainTabIndex = 3);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyBookingTab(),
                                ),
                              ).then((_) {
                                setState(() => _mainTabIndex = 0);
                              });
                            },
                          ),
                          _MainNavButton(
                            title: "Customers",
                            icon: Icons.group_outlined,
                            isActive: _mainTabIndex == 4,
                            onTap: () {
                              setState(() => _mainTabIndex = 4);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ExpertCustomersPage(),
                                ),
                              ).then((_) {
                                setState(() => _mainTabIndex = 0);
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ===== Cards الإحصائيات (Overview) =====
                    LayoutBuilder(
                      builder: (context, c) {
                        final w = c.maxWidth;
                        final cross = w > 1100
                            ? 4
                            : w > 800
                                ? 3
                                : w > 600
                                    ? 2
                                    : 1;
                        return GridView.count(
                          crossAxisCount: cross,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            StatCard(
                              title: 'Services',
                              value: '$totalServices',
                              icon: Icons.home_repair_service,
                            ),
                            StatCard(
                              title: 'Clients',
                              value: '$totalClients',
                              icon: Icons.group,
                            ),
                            StatCard(
                              title: 'Bookings',
                              value: '$totalBookings',
                              icon: Icons.event_available,
                            ),
                            const StatCard(
                              title: 'Wallet',
                              value: '\$1,260',
                              icon: Icons.account_balance_wallet,
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // مساحة لأي Widgets إضافية لاحقًا
                    const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),

          // 🔔 Overlay بسيط للإشعارات
          if (_notifOpen) _buildNotificationsOverlay(context),
        ],
      ),
    );
  }

  Widget _buildNotificationsOverlay(BuildContext context) {
    return Positioned(
      right: 30,
      top: 80,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _loadingNotifs
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            : _notifications.isEmpty
                ? const Text(
                    "No new notifications",
                    style: TextStyle(color: Colors.grey),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _notifications.take(5).map((notif) {
                      final title = notif['title'] ?? "Notification";
                      final message = notif['message'] ?? "";
                      final type = notif['type'] ?? 'info';
                      final Color base = (type == 'success')
                          ? Colors.green
                          : (type == 'error')
                              ? Colors.redAccent
                              : (type == 'warning')
                                  ? Colors.orange
                                  : Colors.blueAccent;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: base.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: base.withOpacity(0.35)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notifications, color: base),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
      ),
    );
  }
}

// ====================
//  زر التبويب الرئيسي
// ====================
class _MainNavButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _MainNavButton({
    required this.title,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = const Color(0xFF285E6E);
    final Color borderColor = const Color(0xFFD3E3EC);

    if (isActive) {
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  colors: [Color(0xFF62C6D9), Color(0xFF2F8CA5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: activeColor.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: activeColor.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
