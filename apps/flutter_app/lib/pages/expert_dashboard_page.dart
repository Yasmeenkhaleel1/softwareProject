// lib/pages/expert_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/stat_card.dart';
import 'edit_expert_profile_page.dart';
import 'view_expert_profile_page.dart';
import 'my_services_page.dart';
import 'my_booking_tab.dart';
import '../services/notifications_api.dart';
import 'chat/conversations_page.dart';
import 'expert_customers_page.dart';
import 'my_availability_page.dart';
import 'expert_earnings_page.dart';
import '../config/api_config.dart';
import '../services/notif_badge.dart';
import 'notifications_page.dart';
class ExpertDashboardPage extends StatefulWidget {
  const ExpertDashboardPage({super.key});

  @override
  State<ExpertDashboardPage> createState() => _ExpertDashboardPageState();
}

class _ExpertDashboardPageState extends State<ExpertDashboardPage> {
  // =========== STATE ===========
  // الإحصائيات
  int totalServices = 0;
  int totalBookings = 0;
  int totalClients = 0;
  double _wallet = 0;

  // البروفايل
  bool _loadingMe = true;
  Map<String, dynamic>? _me;

  // الإشعارات
  bool _notifOpen = false;
  bool _loadingNotifs = true;
  List<dynamic> _notifications = [];

  // Stripe Connect
  bool _stripeLoading = true;
  bool _stripeConnected = false;
  bool _payoutsEnabled = false;
  bool _detailsSubmitted = false;

  // التنقل
  int _mainTabIndex = 0;
  int _mobileBottomNavIndex = 0;

  // العرض
  late bool _isMobile;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    NotifBadge.refresh();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadMe(),
      _loadDashboardStats(),
      _fetchNotifications(),
      _loadStripeStatus(),
    ]);
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // =========== API CALLS ===========
  Future<void> _loadDashboardStats() async {
    try {
      final token = await _getToken();
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
      }

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
        setState(() => _loadingMe = false);
      }
    } catch (e) {
      debugPrint("loadMe error: $e");
      setState(() => _loadingMe = false);
    }
  }

  Future<void> _fetchNotifications() async {
  try {
    final items = await NotificationsAPI.getAll();
    setState(() {
      _notifications = items;
      _loadingNotifs = false;
    });
  } catch (e) {
    debugPrint("Error fetching notifications: $e");
    setState(() => _loadingNotifs = false);
  }
}


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
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      }
    } catch (e) {
      debugPrint("Stripe connect link error: $e");
    }
  }

  // =========== EDIT PROFILE LOGIC ===========
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

  // =========== NAVIGATION ===========
  void _onMobileBottomNavTapped(int index) {
    setState(() {
      _mobileBottomNavIndex = index;
      _mainTabIndex = index;
    });

    final routes = [
      () => null, // 0 - Overview (يبقى في نفس الصفحة)
      () => const ViewExpertProfilePage(),
      () => const MyServicesPage(),
      () => const MyBookingTab(),
      () => const ExpertCustomersPage(),
      () => const ExpertEarningsPage(),
      () => const MyAvailabilityPage(),
    ];

    if (index > 0 && index < routes.length) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => routes[index]()!),
      ).then((_) {
        setState(() {
          _mobileBottomNavIndex = 0;
          _mainTabIndex = 0;
        });
      });
    }
  }

  void _onWebTabTapped(int index) {
    setState(() => _mainTabIndex = index);
    
    final routes = [
      () => null, // 0 - Overview
      () => const ViewExpertProfilePage(),
      () => const MyServicesPage(),
      () => const MyBookingTab(),
      () => const ExpertCustomersPage(),
      () => const ExpertEarningsPage(),
      () => const MyAvailabilityPage(),
    ];

    if (index > 0 && index < routes.length) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => routes[index]()!),
      ).then((_) {
        setState(() => _mainTabIndex = 0);
      });
    }
  }

  // =========== UI BUILD ===========
  @override
  Widget build(BuildContext context) {
    _isMobile = MediaQuery.of(context).size.width < 768;
    
    // تحضير بيانات البروفايل
    final profileData = _getProfileData();
    
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(profileData),
      bottomNavigationBar: _isMobile ? _buildMobileBottomNav() : null,
    );
  }

  Map<String, dynamic> _getProfileData() {
    String displayName = "Expert";
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

      final String? rawImageUrl = (approved?['profileImageUrl'] ??
          pending?['profileImageUrl'] ??
          draft?['profileImageUrl'] ??
          profile?['profileImageUrl']) as String?;

      imageUrl = rawImageUrl != null && rawImageUrl.isNotEmpty
          ? ApiConfig.fixAssetUrl(rawImageUrl)
          : null;

      final num rawRating = (active['ratingAvg'] ?? 0) as num;
      ratingAvg = rawRating.toDouble();
      ratingCount = (active['ratingCount'] ?? 0) as int;
    }

    return {
      'displayName': displayName,
      'specialization': specialization,
      'bio': bio,
      'imageUrl': imageUrl,
      'ratingAvg': ratingAvg,
      'ratingCount': ratingCount,
    };
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF3CB8D4),
      titleSpacing: 24,
      title: Row(
        children: const [
          Icon(Icons.auto_awesome, color: Colors.white),
          SizedBox(width: 8),
          Text(
            'Expert ',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
      actions: [
        _buildMessageButton(),
        _buildNotificationsButton(),
        const SizedBox(width: 8),
      ],
    );
  }

Widget _buildMessageButton() {
  return IconButton(
    icon: const Icon(Icons.message_outlined, color: Colors.white),
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConversationsPage()),
      );
      // لو لاحقًا بدك badge للمسجات: بنعمل MessageBadge + API خاص بالـ unread chats
    },
  );
}


Widget _buildNotificationsButton() {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        icon: const Icon(Icons.notifications_none, color: Colors.white),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          );

          await NotifBadge.refresh();
          await _fetchNotifications();
          setState(() {});
        },
      ),

      // ✅ Badge (لا يلتقط الضغط + حجم أصغر)
      Positioned(
        right: 6,
        top: 6,
        child: IgnorePointer(
          ignoring: true, // ⭐ مهم: خلي الضغط يروح للـ IconButton
          child: ValueListenableBuilder<int>(
            valueListenable: NotifBadge.unread,
            builder: (context, count, _) {
              if (count <= 0) return const SizedBox();

              final text = (count > 99) ? "99+" : "$count";

              return Container(
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}


  Widget _buildBody(Map<String, dynamic> profileData) {
    return Stack(
      children: [
        // خلفية
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F8FC), Color(0xFFE5F4F7)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        
        // المحتوى
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // بطاقة البروفايل
                  _buildProfileCard(profileData),
                  
                  const SizedBox(height: 16),
                  
                  // Stripe Banner
                  if (!_stripeLoading) _buildStripeBanner(),
                  
                  // التبويبات
                  if (!_isMobile) ...[
                    const SizedBox(height: 20),
                    _buildWebTabs(),
                  ],
                  
                  // المحتوى الرئيسي
                  const SizedBox(height: 24),
                  _buildMainContent(profileData),
                ],
              ),
            ),
          ),
        ),
        
        // الإشعارات
        if (_notifOpen) _buildNotificationsOverlay(),
      ],
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> profileData) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFEAF9FC)],
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
        border: Border.all(color: const Color(0xFFD7E3EE), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // الصورة
          CircleAvatar(
            radius: _isMobile ? 30 : 38,
            backgroundImage: profileData['imageUrl'] != null
                ? NetworkImage(profileData['imageUrl']!)
                : const AssetImage('assets/images/experts.png') as ImageProvider,
          ),
          
          const SizedBox(width: 18),
          
          // المعلومات
          Expanded(
            child: _loadingMe
                ? const LinearProgressIndicator(minHeight: 2)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profileData['displayName'],
                        style: TextStyle(
                          fontSize: _isMobile ? 18 : 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      
                      if (profileData['specialization'].isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          profileData['specialization'],
                          style: TextStyle(
                            fontSize: _isMobile ? 13 : 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            profileData['ratingAvg'].toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "/5  ·  ${profileData['ratingCount']} reviews",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      if (profileData['bio'].isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          profileData['bio'],
                          maxLines: _isMobile ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _isMobile ? 12 : 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          
          const SizedBox(width: 16),
          
          // زر التعديل
          if (!_isMobile)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3CB8D4),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: _loadingMe ? null : _onEditProfilePressed,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          else
            IconButton(
              onPressed: _loadingMe ? null : _onEditProfilePressed,
              icon: const Icon(Icons.edit, color: Color(0xFF3CB8D4)),
            ),
        ],
      ),
    );
  }

  Widget _buildWebTabs() {
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
        border: Border.all(color: const Color(0xFFE0E7F1), width: 1),
      ),
      child: Row(
        children: [
          _buildTabButton(
            title: "Overview",
            icon: Icons.insights_outlined,
            index: 0,
          ),
          _buildTabButton(
            title: "Profile",
            icon: Icons.person_outline,
            index: 1,
          ),
          _buildTabButton(
            title: "Services",
            icon: Icons.home_repair_service_outlined,
            index: 2,
          ),
          _buildTabButton(
            title: "Bookings",
            icon: Icons.event_available_outlined,
            index: 3,
          ),
          _buildTabButton(
            title: "Customers",
            icon: Icons.group_outlined,
            index: 4,
          ),
          _buildTabButton(
            title: "Earnings",
            icon: Icons.attach_money_outlined,
            index: 5,
          ),
          _buildTabButton(
            title: "Availability",
            icon: Icons.schedule_outlined,
            index: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isActive = _mainTabIndex == index;
    
    return Expanded(
      child: InkWell(
        onTap: () => _onWebTabTapped(index),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: isActive
                ? const LinearGradient(
                    colors: [Color(0xFF62C6D9), Color(0xFF2F8CA5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isActive ? null : Colors.white,
            border: isActive ? null : Border.all(color: const Color(0xFFD3E3EC)),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : const Color(0xFF285E6E).withOpacity(0.7),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF285E6E).withOpacity(0.85),
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(Map<String, dynamic> profileData) {
    if (_isMobile) {
      return _buildMobileContent();
    } else {
      return _buildDesktopContent();
    }
  }

  Widget _buildMobileContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // الإحصائيات
        const Text(
          "Dashboard Overview",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildStatsGrid(),
        
        // Quick Actions
        const SizedBox(height: 24),
        _buildMobileQuickActions(),
        
        // Earnings Chart
        const SizedBox(height: 24),
        _buildEarningsChartCard(),
        
        // Performance Tips
        const SizedBox(height: 24),
        _buildInfoCard(),
      ],
    );
  }

  Widget _buildDesktopContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // العمود الأيسر
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
        
        // العمود الأيمن
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
    );
  }

 Widget _buildStatsGrid() {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      int crossAxisCount;
      double childAspectRatio;
      EdgeInsets padding;
      
      if (_isMobile) {
        // 📱 موبايل: 2x2 مع حجم أصغر
        crossAxisCount = 2;
        childAspectRatio = 1.2; // جعلهم أكثر مربعية
        padding = const EdgeInsets.symmetric(horizontal: 8); // تقليل المساحة الجانبية
      } else if (width >= 1100) {
        // 💻 ديسكتوب كبير
        crossAxisCount = 4;
        childAspectRatio = 1.25;
        padding = EdgeInsets.zero;
      } else if (width >= 800) {
        // 📱 تابلت
        crossAxisCount = 3;
        childAspectRatio = 1.3;
        padding = EdgeInsets.zero;
      } else {
        // 📱 موبايل صغير جداً
        crossAxisCount = 2;
        childAspectRatio = 1.1;
        padding = const EdgeInsets.symmetric(horizontal: 4);
      }
      
      return Padding(
        padding: padding,
        child: GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: _isMobile ? 12 : 16, // تقليل المسافة في الجوال
          mainAxisSpacing: _isMobile ? 12 : 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: [
            // استخدام StatCard معدل للجوال
            _buildMobileStatCard(
              title: 'Services',
              value: '$totalServices',
              icon: Icons.home_repair_service,
            ),
            _buildMobileStatCard(
              title: 'Clients',
              value: '$totalClients',
              icon: Icons.group,
            ),
            _buildMobileStatCard(
              title: 'Bookings',
              value: '$totalBookings',
              icon: Icons.event_available,
            ),
            _buildMobileStatCard(
              title: 'Wallet',
              value: '\$${_wallet.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet,
            ),
          ],
        ),
      );
    },
  );
}

// 📱 نسخة معدلة من StatCard للجوال
Widget _buildMobileStatCard({
  required String title,
  required String value,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(
        color: const Color(0xFFE5F4F7),
        width: 1,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF3CB8D4).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: const Color(0xFF3CB8D4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildMobileQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
            Icon(icon, color: const Color(0xFF3CB8D4), size: 24),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyServicesPage()),
                ),
              ),
              _QuickActionChip(
                icon: Icons.event_available_outlined,
                label: "View bookings",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingTab()),
                ),
              ),
              _QuickActionChip(
                icon: Icons.attach_money_outlined,
                label: "Check earnings",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ExpertEarningsPage()),
                ),
              ),
              _QuickActionChip(
                icon: Icons.schedule_outlined,
                label: "Edit availability",
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyAvailabilityPage()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildEarningsChartCard() {
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
          height: _isMobile ? 150 : 180,
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
                      final labels = ['Week 1', 'Week 2', 'Week 3', 'Now'];
                      final index = value.toInt();
                      if (index >= 0 && index < labels.length) {
                        return Text(
                          labels[index],
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  barWidth: 3,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3CB8D4), Color(0xFF285E6E)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  dotData: FlDotData(show: true),
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
        ? "You've started onboarding with Stripe. Please complete the remaining steps to receive payouts."
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
            child: const Icon(Icons.account_balance_wallet_outlined,
                color: Color(0xFF3CB8D4)),
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
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3CB8D4),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            onPressed: _openStripeOnboarding,
            icon: const Icon(Icons.open_in_new, size: 18, color: Colors.white),
            label: Text(
              hasStarted ? "Continue" : "Connect",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildNotificationsOverlay() {
    return Positioned(
      right: _isMobile ? 16 : 30,
      top: 80,
      child: Container(
        width: _isMobile ? MediaQuery.of(context).size.width * 0.9 : 320,
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
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? const Text("No new notifications", style: TextStyle(color: Colors.grey))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: _notifications.take(5).map((notif) {
  final title = (notif['title'] ?? "Notification").toString();
  final body  = (notif['body'] ?? "").toString();
  final readAt = notif['readAt']; // null => unread
  final isUnread = readAt == null;
  final link = (notif['link'] ?? "").toString();
  final id = (notif['_id'] ?? "").toString();

  final base = isUnread ? Colors.blueAccent : Colors.grey;

  return InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () async {
      // ✅ read
      if (id.isNotEmpty && isUnread) {
        await NotificationsAPI.markOneAsRead(id);
        await NotifBadge.refresh();
        await _fetchNotifications();
      }

      // ✅ navigation (اختياري)
      if (link.isNotEmpty) {
        // TODO: router حسب link
      }
    },
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: base.withOpacity(isUnread ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: base.withOpacity(0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isUnread ? Icons.notifications_active : Icons.notifications_none,
            color: base,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}).toList(),

                  ),
      ),
    );
  }
}

// =========== Helper Widgets ===========

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
          border: Border.all(color: Colors.white.withOpacity(0.25)),
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
          child: Icon(icon, size: 18, color: color),
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
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}