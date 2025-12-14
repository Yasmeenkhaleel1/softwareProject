// lib/pages/expert_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart'; // 📈 للـ Charts

import '../widgets/stat_card.dart';
import 'edit_expert_profile_page.dart';
import 'view_expert_profile_page.dart';
import 'my_services_page.dart';
import 'my_booking_tab.dart';
import 'notifications_page.dart';
import '../services/notifications_api.dart';
import 'chat/conversations_page.dart';
import 'expert_customers_page.dart';
import 'my_availability_page.dart';
import 'expert_earnings_page.dart';
import '../config/api_config.dart';

class ExpertDashboardPage extends StatefulWidget {
  const ExpertDashboardPage({super.key});

  @override
  State<ExpertDashboardPage> createState() => _ExpertDashboardPageState();
}

class _ExpertDashboardPageState extends State<ExpertDashboardPage> {
  int totalServices = 0;
  int totalBookings = 0;
  int totalClients = 0;
  double _wallet = 0;

  bool _loadingMe = true;
  Map<String, dynamic>? _me;

  bool _notifOpen = false;
  bool _loadingNotifs = true;
  List<dynamic> _notifications = [];

  // 🔹 حالة Stripe Connect
  bool _stripeLoading = true;
  bool _stripeConnected = false;
  bool _payoutsEnabled = false;
  bool _detailsSubmitted = false;

  // 0 = Overview | 1 = Profile | 2 = Services | 3 = Bookings | 4 = Customers | 5 = Availability | 6 = My Earnings
  int _mainTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _fetchNotifications();
    _loadDashboardStats();
    _loadStripeStatus();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _loadDashboardStats() async {
    try {
      final token = await _getToken();

      // 1) إحصائيات الداشبورد (services / bookings / clients)
      final dashRes = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/expert/dashboard"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (dashRes.statusCode == 200) {
        final data = jsonDecode(dashRes.body);

        setState(() {
          totalServices = data['services'] ?? 0;
          totalBookings = data['bookings'] ?? 0;
          totalClients = data['clients'] ?? 0;
        });
      } else {
        debugPrint(
          "Dashboard stats failed: ${dashRes.statusCode} ${dashRes.body}",
        );
      }

      // 2) الأرباح الفعلية (Wallet) من /api/expert/earnings/summary
      final earnRes = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/expert/earnings/summary"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (earnRes.statusCode == 200) {
        final earnData = jsonDecode(earnRes.body);

        final walletRaw = earnData['totalNetToExpert'] ?? 0;

        setState(() {
          _wallet = (walletRaw is int)
              ? walletRaw.toDouble()
              : (walletRaw is double)
                  ? walletRaw
                  : double.tryParse(walletRaw.toString()) ?? 0.0;
        });
      } else {
        debugPrint(
          "Earnings summary failed: ${earnRes.statusCode} ${earnRes.body}",
        );
      }
    } catch (e) {
      debugPrint("Dashboard stats error: $e");
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
        debugPrint(
          "Create draft from approved failed: ${res.statusCode} ${res.body}",
        );
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

  // =========================
  //    Stripe Connect logic
  // =========================
  Future<void> _loadStripeStatus() async {
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/api/payments/connect/status"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _stripeConnected = data['connected'] == true;
          _payoutsEnabled = data['payoutsEnabled'] == true;
          _detailsSubmitted = data['detailsSubmitted'] == true;
          _stripeLoading = false;
        });
      } else {
        debugPrint("Stripe status failed: ${res.statusCode} ${res.body}");
        setState(() => _stripeLoading = false);
      }
    } catch (e) {
      debugPrint("Stripe status error: $e");
      setState(() => _stripeLoading = false);
    }
  }

  Future<void> _openStripeOnboarding() async {
    try {
      final token = await _getToken();
      final res = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/api/payments/connect/link"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final url = data['url'] as String?;
        if (url != null && url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );
          } else {
            debugPrint("Cannot launch Stripe onboarding URL");
          }
        }
      } else {
        debugPrint("Stripe connect link failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Stripe connect link error: $e");
    }
  }

  // =========================
  //         UI
  // =========================
  @override
  Widget build(BuildContext context) {
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

    // ===== تجهيز بيانات البروفايل + التقييم =====
    String displayName = "Unknown Expert";
    String specialization = "";
    String bio = "";
    String? imageUrl;

    double ratingAvg = 0.0;
    int ratingCount = 0;

    if (_me != null) {
      final user = _me!['user'] ?? {};
      final approved = _me!['approvedProfile'];
      final pending = _me!['pendingProfile'];
      final draft = _me!['draftProfile'];
      final profile = _me!['profile'];

      final active = approved ?? pending ?? draft ?? profile ?? {};

      displayName = (approved?['name'] ??
              pending?['name'] ??
              draft?['name'] ??
              profile?['name'] ??
              user['name'] ??
              "Unknown Expert") as String;

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

      final num rawRating = (active['ratingAvg'] ?? 0) as num;
      ratingAvg = rawRating.toDouble();
      ratingCount = (active['ratingCount'] ?? 0) as int;
    }

    // ✅ إصلاح رابط الصورة
    String avatarUrl = '';
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatarUrl = ApiConfig.fixAssetUrl(imageUrl);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1100;
    final maxWidth =
        isDesktop ? 1300.0 : (screenWidth > 1200 ? 1100.0 : screenWidth * 0.95);

    return Scaffold(
      appBar: appBar,
      body: Stack(
        children: [
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
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isDesktop
                    ? _buildDesktopLayout(
                        avatarUrl: avatarUrl,
                        displayName: displayName,
                        specialization: specialization,
                        bio: bio,
                        ratingAvg: ratingAvg,
                        ratingCount: ratingCount,
                      )
                    : _buildMobileLayout(
                        avatarUrl: avatarUrl,
                        displayName: displayName,
                        specialization: specialization,
                        bio: bio,
                        ratingAvg: ratingAvg,
                        ratingCount: ratingCount,
                      ),
              ),
            ),
          ),

          if (_notifOpen) _buildNotificationsOverlay(context),
        ],
      ),
    );
  }

  // =========================
  //  Responsive Layouts
  // =========================

  Widget _buildMobileLayout({
    required String avatarUrl,
    required String displayName,
    required String specialization,
    required String bio,
    required double ratingAvg,
    required int ratingCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileCard(
          avatarUrl: avatarUrl,
          displayName: displayName,
          specialization: specialization,
          bio: bio,
          ratingAvg: ratingAvg,
          ratingCount: ratingCount,
        ),
        const SizedBox(height: 16),
        if (!_stripeLoading) _buildStripeBanner(),
        if (!_stripeLoading) const SizedBox(height: 16),
        _buildMainTabs(),
        const SizedBox(height: 24),
        const Text(
          "Overview",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _buildEarningsChartCard(),
        const SizedBox(height: 24),
        _buildQuickActionsCard(),
      ],
    );
  }

  Widget _buildDesktopLayout({
    required String avatarUrl,
    required String displayName,
    required String specialization,
    required String bio,
    required double ratingAvg,
    required int ratingCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileCard(
          avatarUrl: avatarUrl,
          displayName: displayName,
          specialization: specialization,
          bio: bio,
          ratingAvg: ratingAvg,
          ratingCount: ratingCount,
        ),
        const SizedBox(height: 16),
        if (!_stripeLoading) _buildStripeBanner(),
        if (!_stripeLoading) const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // يسار: Tabs + Stats + Quick actions
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMainTabs(),
                  const SizedBox(height: 20),
                  const Text(
                    "Overview",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildStatsGrid(),
                  const SizedBox(height: 24),
                  _buildQuickActionsCard(),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // يمين: Earnings chart + Info card
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _buildEarningsChartCard(),
                  const SizedBox(height: 16),
                  _buildInfoCard(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =========================
  //  Reusable UI Sections
  // =========================

  Widget _buildProfileCard({
    required String avatarUrl,
    required String displayName,
    required String specialization,
    required String bio,
    required double ratingAvg,
    required int ratingCount,
  }) {
    return Container(
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
            backgroundImage: avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : const AssetImage('assets/images/experts.png')
                    as ImageProvider,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: _loadingMe
                ? const LinearProgressIndicator(minHeight: 2)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 18,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ratingAvg.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "/5  ·  $ratingCount reviews",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          bio,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
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
            onPressed: _loadingMe ? null : _onEditProfilePressed,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainTabs() {
    return Container(
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: _MainNavButton(
                title: "Overview",
                icon: Icons.insights_outlined,
                isActive: _mainTabIndex == 0,
                onTap: () {
                  setState(() => _mainTabIndex = 0);
                },
              ),
            ),
            SizedBox(
              width: 120,
              child: _MainNavButton(
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
            ),
            SizedBox(
              width: 130,
              child: _MainNavButton(
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
            ),
            SizedBox(
              width: 130,
              child: _MainNavButton(
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
            ),
            SizedBox(
              width: 130,
              child: _MainNavButton(
                title: "Customers",
                icon: Icons.group_outlined,
                isActive: _mainTabIndex == 4,
                onTap: () {
                  setState(() => _mainTabIndex = 4);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpertCustomersPage(),
                    ),
                  ).then((_) {
                    setState(() => _mainTabIndex = 0);
                  });
                },
              ),
            ),
            SizedBox(
              width: 150,
              child: _MainNavButton(
                title: "My Availability",
                icon: Icons.schedule_outlined,
                isActive: _mainTabIndex == 5,
                onTap: () {
                  setState(() => _mainTabIndex = 5);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyAvailabilityPage(),
                    ),
                  ).then((_) {
                    setState(() => _mainTabIndex = 0);
                  });
                },
              ),
            ),
            SizedBox(
              width: 140,
              child: _MainNavButton(
                title: "My Earnings",
                icon: Icons.attach_money_outlined,
                isActive: _mainTabIndex == 6,
                onTap: () {
                  setState(() => _mainTabIndex = 6);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpertEarningsPage(),
                    ),
                  ).then((_) {
                    setState(() => _mainTabIndex = 0);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cross = w > 1100
            ? 4
            : w > 800
                ? 4
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
            StatCard(
              title: 'Wallet',
              value: '\$${_wallet.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
            ),
          ],
        );
      },
    );
  }

  Widget _buildEarningsChartCard() {
  // Trend بسيط مبني على قيمة الـ Wallet الحالية (شكل فقط، بدون داتا حقيقية زمنية)
  final double base = _wallet <= 0 ? 50 : _wallet;
  final spots = [
    FlSpot(0, base * 0.35),
    FlSpot(1, base * 0.55),
    FlSpot(2, base * 0.7),
    FlSpot(3, base),
  ];

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 6),
        ),
      ],
      border: Border.all(color: const Color(0xFFE0E7F1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Earnings trend",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Total wallet: \$${_wallet.toStringAsFixed(2)}",
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withOpacity(0.15),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      "\$${value.toInt()}",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      String label = '';
                      final v = value.toInt();
                      if (v == 0) {
                        label = 'Week 1';
                      } else if (v == 1) {
                        label = 'Week 2';
                      } else if (v == 2) {
                        label = 'Week 3';
                      } else if (v == 3) {
                        label = 'Now';
                      }
                      return Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  // نستخدم gradient عشان نضمن التوافق
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3CB8D4),
                      Color(0xFF285E6E),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  // في 0.66.0 خليه بسيط بدون dotColor / dotSize
                  dotData: FlDotData(
                    show: true,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF3CB8D4).withOpacity(0.4),
                        const Color(0xFF3CB8D4).withOpacity(0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF285E6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick actions",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Manage your services, bookings and earnings in one place.",
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuickActionChip(
                icon: Icons.home_repair_service_outlined,
                label: "Manage services",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyServicesPage(),
                    ),
                  );
                },
              ),
              _QuickActionChip(
                icon: Icons.event_available_outlined,
                label: "View bookings",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyBookingTab(),
                    ),
                  );
                },
              ),
              _QuickActionChip(
                icon: Icons.attach_money_outlined,
                label: "Check earnings",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpertEarningsPage(),
                    ),
                  );
                },
              ),
              _QuickActionChip(
                icon: Icons.schedule_outlined,
                label: "Edit availability",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyAvailabilityPage(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7F1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Performance tips",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.trending_up,
            color: Colors.green,
            title: "Boost your bookings",
            subtitle:
                "Keep your availability up to date and respond quickly to new requests.",
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.star_border,
            color: Colors.amber,
            title: "Improve ratings",
            subtitle:
                "Deliver consistent quality and ask happy customers to leave reviews.",
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.shield_outlined,
            color: Colors.blueAccent,
            title: "Stay verified",
            subtitle:
                "Make sure your profile and Stripe payouts stay fully verified.",
          ),
        ],
      ),
    );
  }

  Widget _buildStripeBanner() {
    // لو كل شيء تمام، نعرض شارة صغيرة فقط
    if (_stripeConnected && _payoutsEnabled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F9F0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF34C38F)),
        ),
        child: Row(
          children: const [
            Icon(Icons.verified, color: Color(0xFF34C38F)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Stripe payouts are active. Your earnings will be transferred automatically.",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF166644),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool hasStarted = _stripeConnected && !_payoutsEnabled;

    final String title = hasStarted
        ? "Complete your Stripe setup"
        : "Connect your payout account";

    final String subtitle = hasStarted
        ? "You’ve started onboarding with Stripe. Please complete the remaining steps to receive payouts."
        : "Connect your account with Stripe to receive your session earnings securely.";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE0E7F1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3CB8D4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFF3CB8D4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3CB8D4),
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _openStripeOnboarding,
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
            label: Text(
              hasStarted ? "Continue" : "Connect",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      );
    }

    return InkWell(
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
    );
  }
}

// ====================
//  Quick Action Chip
// ====================
class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================
//  Info Row
// ====================
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
