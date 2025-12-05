// lib/pages/expert_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/expert_sidebar.dart';
import '../widgets/stat_card.dart';
import 'edit_expert_profile_page.dart';
import 'view_expert_profile_page.dart';
import 'my_services_page.dart';
import 'my_booking_tab.dart';

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

  int _selected = -1;

  bool _loadingMe = true;
  Map<String, dynamic>? _me; // { user, profile, approvedProfile, draftProfile, pendingProfile }

  bool _notifOpen = false;
  bool _loadingNotifs = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadMe();
    _fetchNotifications();
    _loadDashboardStats(); // ✅ أضف هذا
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
  //  Edit button behavior
  // =========================
  Future<void> _onEditProfilePressed() async {
    if (_me == null) return;

    final approved = _me!['approvedProfile'];
    final draft = _me!['draftProfile'];
    final pending = _me!['pendingProfile'];

    if (pending != null) {
      // بانتظار مراجعة — لا تسمح بالتعديل الآن
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("بروفايلك تحت المراجعة حاليًا.")),
      );
      return;
    }

    if (draft != null) {
      // افتح صفحة التعديل على draft الحالي
      _openEditor(draft);
      return;
    }

    // لو عنده approved فقط → أنشئ draft من المعتمد
    if (approved != null) {
      final draftObj = await _createDraftFromApproved(approved);
      if (draftObj != null) _openEditor(draftObj);
      return;
    }

    // لا يملك أي شيء → أنشئ draft فارغ
    final draftObj = await _createEmptyDraft();
    if (draftObj != null) _openEditor(draftObj);
  }

  Future<Map<String, dynamic>?> _createDraftFromApproved(Map<String, dynamic> approved) async {
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
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        // نتوقع data = { draft: {...} }
        setState(() {
          _me!['draftProfile'] = data['draft'];
        });
        return data['draft'];
      } else {
        debugPrint("Create draft from approved failed: ${res.statusCode} ${res.body}");
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
    // بعد الرجوع: حدّث البيانات
    _loadMe();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 1000;

    // ==== Header AppBar with notification bell ====
    final appBar = AppBar(
      backgroundColor: const Color(0xFF62C6D9),
      title: const Text(
        'Expert Dashboard',
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.white),
              onPressed: () => setState(() => _notifOpen = !_notifOpen),
            ),
            if (_notifications.any((n) => n['isRead'] == false))
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );

    final sidebar = ExpertSidebar(
      selectedIndex: _selected,
    onSelected: (i) {
  Navigator.pop(context); // إغلاق drawer إن وجد

  if (i == 0) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ViewExpertProfilePage()),
    ).then((_) {
      setState(() => _selected = -1); // ✅ عند الرجوع
    });
  } else if (i == 1) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyServicesPage()),
    ).then((_) {
      setState(() => _selected = -1); // ✅ عند الرجوع
    });
  } else if (i == 2) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyBookingTab()),
    ).then((_) {
      setState(() => _selected = -1); // ✅ عند الرجوع
    });
  } else if (i == 5) {
    Navigator.popUntil(context, ModalRoute.withName('/'));
  }

  setState(() => _selected = i);
},



    );

    // ====== اختيارات العرض ======
    String displayName = "Unknown Expert";
    String specialization = "";
    String bio = "";

    String? imageUrl;

    if (_me != null) {
      final user = _me!['user'] ?? {};
      final approved = _me!['approvedProfile'];
      final pending = _me!['pendingProfile'];
      final draft = _me!['draftProfile'];
      final profile = _me!['profile']; // قد تكون null

      // الاسم
      displayName = (approved?['name'] ??
          pending?['name'] ??
          draft?['name'] ??
          profile?['name'] ??
          user['name'] ??
          "Unknown Expert") as String;

      // التخصص + البايو
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

      // الصورة
      imageUrl = (approved?['profileImageUrl'] ??
          pending?['profileImageUrl'] ??
          draft?['profileImageUrl'] ??
          profile?['profileImageUrl']) as String?;
    }

    return Scaffold(
      appBar: isWide ? null : appBar,
      drawer: isWide ? null : Drawer(child: sidebar),
      body: Stack(
        children: [
          Row(
            children: [
              if (isWide) sidebar,
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    if (isWide)
                      SliverAppBar(
                        backgroundColor: const Color(0xFF62C6D9),
                        pinned: true,
                        toolbarHeight: 64,
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Expert Dashboard',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                            Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                                  onPressed: () => setState(() => _notifOpen = !_notifOpen),
                                ),
                                if (_notifications.any((n) => n['isRead'] == false))
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== Header (Profile + rating) =====
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                              ),
                              child: Row(
                                children: [
                                  // صورة البروفايل
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundImage: (imageUrl != null && imageUrl.startsWith("http"))
                                        ? NetworkImage(imageUrl)
                                        : const AssetImage('assets/images/experts.png') as ImageProvider,
                                  ),
                                  const SizedBox(width: 16),
                                  // الاسم + تخصص + بايو
                                  Expanded(
                                    child: _loadingMe
                                        ? const LinearProgressIndicator(minHeight: 2)
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              if (specialization.isNotEmpty)
                                                Text(
                                                  specialization,
                                                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                                                ),
                                              if (bio.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  bio,
                                                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                  // زر تعديل الملف
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFF62C6D9),
                                    ),
                                    onPressed: _loadingMe ? null : _onEditProfilePressed,
                                    child: const Text('Edit Profile'),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // ===== Stats Grid (ثابت حالياً) =====
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
  StatCard(title: 'Services', value: '$totalServices', icon: Icons.home_repair_service),
  StatCard(title: 'Clients', value: '$totalClients', icon: Icons.group),
  StatCard(title: 'Bookings', value: '$totalBookings', icon: Icons.event_available),
  const StatCard(title: 'Wallet', value: '\$1,260', icon: Icons.account_balance_wallet),
],

                                );
                              },
                            ),

                            const SizedBox(height: 24),

                            _SelectedSection(index: _selected),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // 🔔 نافذة الإشعارات المنسدلة
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
                child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            : _notifications.isEmpty
                ? const Text("No new notifications", style: TextStyle(color: Colors.grey))
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
                                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(message, style: const TextStyle(fontSize: 13)),
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

class _SelectedSection extends StatelessWidget {
  final int index;
  const _SelectedSection({required this.index});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}



