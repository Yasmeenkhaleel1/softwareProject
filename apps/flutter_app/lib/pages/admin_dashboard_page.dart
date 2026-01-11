// lib/pages/admin_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/landing_page.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import 'admin_expert_page.dart';
import 'admin_payments_page.dart';
import 'admin_disputes_page.dart';
import 'admin_earnings_page.dart';
import '../config/api_config.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ======================
  // MOBILE STATE
  // ======================
  int _mobileIndex = 0;
  late List<Widget> _mobilePages;

  // ======================
  // DATA
  // ======================
  bool loadingStats = true;
  bool loadingExperts = true;

  int totalUsers = 0;
  int totalExperts = 0;
  int totalBookings = 0;
  int totalServices = 0;

  double totalRevenue = 0;
  double platformEarnings = 0;
  double expertEarnings = 0;
  double refundsTotal = 0;

  List<Map<String, dynamic>> monthlyBookings = [];
  List<Map<String, dynamic>> revenueByMonth = [];
  Map<String, dynamic> paymentsByStatus = {};

  List<dynamic> pendingExperts = [];

  // ======================
  // BASE URL
  // ======================
  String getBaseUrl() {
    if (kIsWeb) return "http://localhost:5000";

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return "http://10.0.2.2:5000";
      case TargetPlatform.iOS:
        return "http://localhost:5000";
      default:
        return "http://localhost:5000";
    }
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 5, vsync: this);

    // تهيئة صفحات الموبايل
    _mobilePages = [
      const SizedBox(), // سيتم تعبئته لاحقاً
      const SizedBox(),
      AdminPaymentsPage(),
      AdminEarningsPage(),
      const AdminDisputesPage(),
    ];

    _fetchDashboardStats();
    _fetchPendingExperts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ======================
  // API CALLS
  // ======================
  Future<void> _fetchDashboardStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse("${getBaseUrl()}/api/admin/stats"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final cards = data['cards'] ?? {};
        final charts = data['charts'] ?? {};

        setState(() {
          totalUsers = cards['totalUsers'] ?? 0;
          totalExperts = cards['totalExperts'] ?? 0;
          totalBookings = cards['totalBookings'] ?? 0;
          totalServices = cards['totalServices'] ?? 0;

          totalRevenue = (cards['totalRevenue'] ?? 0).toDouble();
          platformEarnings = (cards['platformEarnings'] ?? 0).toDouble();
          expertEarnings = (cards['expertEarnings'] ?? 0).toDouble();
          refundsTotal = (cards['refundsTotal'] ?? 0).toDouble();

          monthlyBookings =
              List<Map<String, dynamic>>.from(charts['bookingsByMonth'] ?? []);
          revenueByMonth =
              List<Map<String, dynamic>>.from(charts['revenueByMonth'] ?? []);
          paymentsByStatus =
              Map<String, dynamic>.from(charts['paymentsByStatus'] ?? {});

          loadingStats = false;
        });
      } else {
        setState(() => loadingStats = false);
      }
    } catch (_) {
      setState(() => loadingStats = false);
    }
  }

  Future<void> _fetchPendingExperts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse("${getBaseUrl()}/api/admin/experts/pending"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          pendingExperts = data['pending'] ?? [];
          loadingExperts = false;
        });
      } else {
        setState(() => loadingExperts = false);
      }
    } catch (_) {
      setState(() => loadingExperts = false);
    }
  }

  Future<void> _approveExpert(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.patch(
        Uri.parse("${getBaseUrl()}/api/admin/experts/$id/approve"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Expert approved successfully")),
        );
        _fetchPendingExperts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res.statusCode}")),
        );
      }
    } catch (e) {
      debugPrint("❌ Approve error: $e");
    }
  }

  Future<void> _rejectExpert(String id) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reject Expert"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: "Reason for rejection",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.patch(
        Uri.parse("${getBaseUrl()}/api/admin/experts/$id/reject"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"reason": reasonController.text}),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Expert rejected")),
        );
        _fetchPendingExperts();
      }
    } catch (e) {
      debugPrint("Reject error: $e");
    }
  }

  // ======================
  // BUILD
  // ======================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: isMobile ? _buildMobileAppBar() : null,
      body: isMobile ? _buildMobileBody() : _buildWebView(),
      bottomNavigationBar: isMobile ? _buildMobileBottomNav() : null,
    );
  }

  // ======================
  // MOBILE UI
  // ======================
PreferredSizeWidget _buildMobileAppBar() {
  return PreferredSize(
    preferredSize: const Size.fromHeight(70),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF62C6D9),
            Color(0xFF347C8B),
            Color(0xFF244C63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Lost Treasures",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white, // ✅ أبيض
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();

                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => LandingPage(
                      isLoggedIn: false,
                      onLogout: () {},
                    ),
                  ),
                  (_) => false,
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMobileBody() {
    // تحديث صفحات الموبايل ببيانات حية
    _mobilePages = [
      _buildMobileDashboard(),
      _buildPendingExperts(),
      AdminPaymentsPage(),
      AdminEarningsPage(),
      const AdminDisputesPage(),
    ];

    return IndexedStack(
      index: _mobileIndex,
      children: _mobilePages,
    );
  }

  Widget _buildMobileBottomNav() {
    return BottomNavigationBar(
      currentIndex: _mobileIndex,
      onTap: (i) => setState(() => _mobileIndex = i),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2970B8),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
        BottomNavigationBarItem(icon: Icon(Icons.people), label: "Experts"),
        BottomNavigationBarItem(icon: Icon(Icons.payments), label: "Payments"),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "Earnings"),
        BottomNavigationBarItem(icon: Icon(Icons.gavel), label: "Disputes"),
      ],
    );
  }

  // ======================
  // WEB UI
  // ======================
  Widget _buildWebView() {
    return Column(
      children: [
        _buildWebAppBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildWebDashboard(),
              _buildPendingExperts(),
              AdminPaymentsPage(),
              AdminEarningsPage(),
              const AdminDisputesPage(),
            ],
          ),
        ),
      ],
    );
  }

  PreferredSize _buildWebAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(165),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF62C6D9).withOpacity(0.85),
                const Color(0xFF347C8B).withOpacity(0.90),
                const Color(0xFF244C63).withOpacity(0.95),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 4),
              SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * -10),
                    child: child,
                  ),
                ),
                child: const Text(
                  "Admin Dashboard",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Colors.white.withOpacity(0.25),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard_customize), text: "Dashboard"),
                  Tab(icon: Icon(Icons.pending_actions), text: "Experts"),
                  Tab(icon: Icon(Icons.payments), text: "Payments"),
                  Tab(icon: Icon(Icons.show_chart), text: "Earnings"),
                  Tab(icon: Icon(Icons.gavel_outlined), text: "Disputes"),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ======================
  // DASHBOARDS
  // ======================
  Widget _buildWebDashboard() {
    if (loadingStats) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF62C6D9)),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchDashboardStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerGradientCard(),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                StatCard(title: "Users", value: "$totalUsers", icon: Icons.people),
                StatCard(title: "Experts", value: "$totalExperts", icon: Icons.engineering),
                StatCard(title: "Services", value: "$totalServices", icon: Icons.home_repair_service),
                StatCard(title: "Bookings", value: "$totalBookings", icon: Icons.event_available),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: ChartCard(data: monthlyBookings)),
                const SizedBox(width: 20),
                Expanded(child: RevenueChartCard(data: revenueByMonth)),
              ],
            ),
            const SizedBox(height: 24),
            if (paymentsByStatus.isNotEmpty)
              PaymentsStatusPieCard(data: paymentsByStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDashboard() {
    if (loadingStats) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF62C6D9)),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _headerGradientCardMobile(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _miniStat("Users", totalUsers),
                _miniStat("Experts", totalExperts),
                _miniStat("Services", totalServices),
                _miniStat("Bookings", totalBookings),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ChartCard(data: monthlyBookings),
                const SizedBox(height: 20),
                RevenueChartCard(data: revenueByMonth),
                const SizedBox(height: 20),
                if (paymentsByStatus.isNotEmpty)
                  PaymentsStatusPieCard(data: paymentsByStatus),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerGradientCardMobile() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF62C6D9),
            Color(0xFF347C8B),
            Color(0xFF244C63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Platform Earnings Overview",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Track total revenue, expert payouts and refunds in real-time.",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniKpi(
                label: "Total Revenue",
                value: "\$${totalRevenue.toStringAsFixed(2)}",
              ),
              _miniKpi(
                label: "Expert Earnings",
                value: "\$${expertEarnings.toStringAsFixed(2)}",
              ),
              _miniKpi(
                label: "Platform Fees",
                value: "\$${platformEarnings.toStringAsFixed(2)}",
              ),
              _miniKpi(
                label: "Refunds",
                value: "\$${refundsTotal.toStringAsFixed(2)}",
                chipColor: Colors.redAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerGradientCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF62C6D9),
            Color(0xFF347C8B),
            Color(0xFF244C63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Platform Earnings Overview",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Track total revenue, expert payouts and refunds in real-time.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    _miniKpi(
                      label: "Total Revenue",
                      value: "\$${totalRevenue.toStringAsFixed(2)}",
                    ),
                    _miniKpi(
                      label: "Expert Earnings",
                      value: "\$${expertEarnings.toStringAsFixed(2)}",
                    ),
                    _miniKpi(
                      label: "Platform Fees",
                      value: "\$${platformEarnings.toStringAsFixed(2)}",
                    ),
                    _miniKpi(
                      label: "Refunds",
                      value: "\$${refundsTotal.toStringAsFixed(2)}",
                      chipColor: Colors.redAccent,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "Live Analytics",
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Your dashboard provides real-time insights into platform performance.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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

  Widget _miniKpi({
    required String label,
    required String value,
    Color chipColor = Colors.greenAccent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String title, int value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "$value",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ======================
  // PENDING EXPERTS
  // ======================
  Widget _buildPendingExperts() {
    if (loadingExperts) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF62C6D9)),
      );
    }

    if (pendingExperts.isEmpty) {
      return const Center(
        child: Text(
          "No pending experts found.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingExperts.length,
      itemBuilder: (context, index) {
      
        final expert = pendingExperts[index];
        final user = expert['userId'] ?? {};
        final displayName = user['name'] ?? expert['name'] ?? "Unknown Expert";
        final email = user['email'] ?? "";
       final raw = (expert['profileImageUrl']
        ?? (expert['profile']?['profileImageUrl'])
        ?? (expert['expertProfile']?['profileImageUrl'])
        ?? '').toString();
final profileImageUrl = ApiConfig.fixAssetUrl(
  raw.isNotEmpty ? raw : "/uploads/profile_pictures.png",
);


        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
           leading: CircleAvatar(
  radius: 25,
  backgroundColor: const Color(0xFF62C6D9).withOpacity(0.15),
  backgroundImage: profileImageUrl.isNotEmpty
      ? NetworkImage(profileImageUrl)
      : const AssetImage('assets/images/profile_placeholder.png') as ImageProvider,
),

            title: Row(
  children: [
    Expanded(
      child: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    const SizedBox(width: 10),
    ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminExpertPage(expertId: expert['_id']),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF347C8B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        "View",
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  ],
),

            subtitle: Text(email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _approveExpert(expert['_id']),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.redAccent),
                  onPressed: () => _rejectExpert(expert['_id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ============================================
   📈 Revenue Chart (Line chart - Admin)
   ============================================ */

class RevenueChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const RevenueChartCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final months = <FlSpot>[];
    final netSpots = <FlSpot>[];
    double maxY = 0;

    for (final row in data) {
      final month = (row['month'] ?? 0).toDouble();
      final revenue = (row['revenue'] ?? 0).toDouble();
      final net = (row['netToExpert'] ?? 0).toDouble();

      if (month == 0) continue;
      months.add(FlSpot(month, revenue));
      netSpots.add(FlSpot(month, net));

      if (revenue > maxY) maxY = revenue;
      if (net > maxY) maxY = net;
    }

    if (maxY == 0) maxY = 1;

    const primary = Color(0xFF62C6D9);
    const accent = Color(0xFF244C63);

    final isMobile = MediaQuery.of(context).size.width < 760;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Revenue vs Expert Earnings",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Track how much the platform earns vs how much goes to experts.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: isMobile ? 180 : 200,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: 12,
                maxY: maxY * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withOpacity(0.1),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          "\$${value.toInt()}",
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (value, meta) {
                        const labels = [
                          "",
                          "Jan",
                          "Feb",
                          "Mar",
                          "Apr",
                          "May",
                          "Jun",
                          "Jul",
                          "Aug",
                          "Sep",
                          "Oct",
                          "Nov",
                          "Dec"
                        ];
                        final idx = value.toInt();
                        if (idx < 1 || idx > 12) return const SizedBox();
                        return Text(
                          labels[idx],
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: months,
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primary.withOpacity(0.2),
                          primary.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  LineChartBarData(
                    spots: netSpots,
                    isCurved: true,
                    color: accent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _LegendDot(color: primary, label: "Total revenue"),
              SizedBox(width: 16),
              _LegendDot(color: accent, label: "Net to experts"),
            ],
          ),
        ],
      ),
    );
  }
}

/* ============================================
   🥧 Payments Status Pie (Admin)
   ============================================ */

class PaymentsStatusPieCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const PaymentsStatusPieCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final importantStatuses = [
      "AUTHORIZED",
      "CAPTURED",
      "REFUND_PENDING",
      "REFUNDED",
      "FAILED",
    ];

    final entries = <Map<String, dynamic>>[];
    int totalCount = 0;

    for (final status in importantStatuses) {
      final row = data[status];
      if (row == null) continue;
      final count = (row['count'] ?? 0) as int;
      if (count == 0) continue;
      totalCount += count;
      entries.add({
        "status": status,
        "count": count,
      });
    }

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Text(
          "No payment status data yet.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final colors = [
      const Color(0xFF62C6D9),
      const Color(0xFF347C8B),
      const Color(0xFF244C63),
      Colors.orangeAccent,
      Colors.redAccent,
    ];

    final isMobile = MediaQuery.of(context).size.width < 760;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              children: [
                const Text(
                  "Payments Status Breakdown",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF1F2933),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "See how many payments are captured, refunded or still pending.",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: List.generate(entries.length, (i) {
                        final e = entries[i];
                        final count = e['count'] as int;
                        final percent = (count / totalCount) * 100;
                        return PieChartSectionData(
                          value: count.toDouble(),
                          color: colors[i % colors.length],
                          radius: 70,
                          title: "${percent.toStringAsFixed(1)}%",
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(entries.length, (i) {
                  final e = entries[i];
                  final count = e['count'] as int;
                  final status = e['status'] as String;
                  final percent = (count / totalCount) * 100;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[i % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          "$count • ${percent.toStringAsFixed(1)}%",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: List.generate(entries.length, (i) {
                          final e = entries[i];
                          final count = e['count'] as int;
                          final percent = (count / totalCount) * 100;
                          return PieChartSectionData(
                            value: count.toDouble(),
                            color: colors[i % colors.length],
                            radius: 70,
                            title: "${percent.toStringAsFixed(1)}%",
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payments Status Breakdown",
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1F2933),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "See how many payments are captured, refunded or still pending.",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(entries.length, (i) {
                        final e = entries[i];
                        final count = e['count'] as int;
                        final status = e['status'] as String;
                        final percent = (count / totalCount) * 100;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colors[i % colors.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                "$count • ${percent.toStringAsFixed(1)}%",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color.fromARGB(255, 253, 142, 142)),
        ),
      ],
    );
  }
}