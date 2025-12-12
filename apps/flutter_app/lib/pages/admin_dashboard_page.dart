// lib/pages/admin_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import 'admin_expert_page.dart';
import 'admin_payments_page.dart';
import 'admin_disputes_page.dart';
import 'admin_earnings_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  static const baseUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
        Uri.parse("$baseUrl/api/admin/stats"),
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
        Uri.parse("$baseUrl/api/admin/experts/pending"),
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
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final res = await http.patch(
      Uri.parse("$baseUrl/api/admin/experts/$id/approve"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      _fetchPendingExperts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expert approved successfully")),
      );
    }
  }

  Future<void> _rejectExpert(String id) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reject Expert"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Reason",
            border: OutlineInputBorder(),
          ),
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

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    await http.patch(
      Uri.parse("$baseUrl/api/admin/experts/$id/reject"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"reason": controller.text}),
    );

    _fetchPendingExperts();
  }

  // ======================
  // BUILD
  // ======================

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: isMobile
          ? PreferredSize(
              preferredSize: const Size.fromHeight(160),
              child: _buildMobileAppBar(),
            )
          : _buildWebAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          isMobile ? _buildMobileDashboard() : _buildWebDashboard(),
          _buildPendingExperts(isMobile),
          AdminPaymentsPage(),
          AdminEarningsPage(),
          const AdminDisputesPage(),
        ],
      ),
    );
  }

  // ======================
  // WEB UI (ORIGINAL)
  // ======================

  PreferredSize _buildWebAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(165),
      child: Container(
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
            const SizedBox(height: 40),
            const Text(
              "Admin Dashboard",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              tabs: const [
                Tab(text: "Dashboard"),
                Tab(text: "Experts"),
                Tab(text: "Payments"),
                Tab(text: "Earnings"),
                Tab(text: "Disputes"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebDashboard() {
    if (loadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              StatCard(title: "Users", value: "$totalUsers", icon: Icons.people),
              StatCard(
                  title: "Experts",
                  value: "$totalExperts",
                  icon: Icons.engineering),
              StatCard(
                  title: "Services",
                  value: "$totalServices",
                  icon: Icons.home_repair_service),
              StatCard(
                  title: "Bookings",
                  value: "$totalBookings",
                  icon: Icons.event_available),
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
        ],
      ),
    );
  }

  // ======================
  // MOBILE UI
  // ======================

 Widget _buildMobileAppBar() {
  return SliverAppBar(
    expandedHeight: 120,
    collapsedHeight: 70,
    floating: true,
    pinned: true,
    flexibleSpace: FlexibleSpaceBar(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF6EC1E4),
              Color(0xFF2970B8),
              Color(0xFF0F3D67)
            ],
          ),
        ),
      ),
      title: const Text(
        "Admin Dashboard",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(48),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(icon: Icon(Icons.dashboard, size: 22)),
          Tab(icon: Icon(Icons.person, size: 22)),
          Tab(icon: Icon(Icons.payments, size: 22)),
          Tab(icon: Icon(Icons.show_chart, size: 22)),
          Tab(icon: Icon(Icons.gavel, size: 22)),
        ],
      ),
    ),
  );
}
  Widget _buildMobileDashboard() {
    if (loadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _mobileHeaderCard(),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _miniStat("Users", totalUsers),
              _miniStat("Experts", totalExperts),
              _miniStat("Services", totalServices),
              _miniStat("Bookings", totalBookings),
            ],
          ),
          const SizedBox(height: 20),
          ChartCard(data: monthlyBookings),
          const SizedBox(height: 20),
          RevenueChartCard(data: revenueByMonth),
          const SizedBox(height: 20),
          PaymentsStatusPieCard(data: paymentsByStatus),
        ],
      ),
    );
  }

  Widget _mobileHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6EC1E4),
            Color(0xFF2970B8),
            Color(0xFF0F3D67)
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _kpiChip("Revenue", totalRevenue),
          _kpiChip("Experts", expertEarnings),
          _kpiChip("Platform", platformEarnings),
          _kpiChip("Refunds", refundsTotal),
        ],
      ),
    );
  }

  Widget _kpiChip(String label, double value) {
    return Chip(
      label: Text("$label: \$${value.toStringAsFixed(0)}",
          style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.white.withOpacity(0.15),
    );
  }

  Widget _miniStat(String title, int value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text("$value",
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(title, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // ======================
  // PENDING EXPERTS
  // ======================

  Widget _buildPendingExperts(bool isMobile) {
    if (loadingExperts) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pendingExperts.isEmpty) {
      return const Center(child: Text("No pending experts found"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingExperts.length,
      itemBuilder: (_, i) {
        final e = pendingExperts[i];
        final user = e['userId'] ?? {};
        final name = user['name'] ?? "Unknown";
        final email = user['email'] ?? "";

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(name),
            subtitle: Text(email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approveExpert(e['_id'])),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => _rejectExpert(e['_id'])),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ======================
// PIE CHART
// ======================

class PaymentsStatusPieCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const PaymentsStatusPieCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text("No payment data available");
    }

    final sections = <PieChartSectionData>[];
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.red
    ];

    int i = 0;
    data.forEach((k, v) {
      sections.add(
        PieChartSectionData(
          value: (v['count'] ?? 0).toDouble(),
          title: k,
          color: colors[i++ % colors.length],
        ),
      );
    });

    return SizedBox(
      height: 220,
      child: PieChart(PieChartData(sections: sections)),
    );
  }
}
// ======================
// REVENUE LINE CHART
// ======================

class RevenueChartCard extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const RevenueChartCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final revenueSpots = <FlSpot>[];
    final expertSpots = <FlSpot>[];
    double maxY = 0;

    for (final row in data) {
      final month = (row['month'] ?? 0).toDouble();
      final revenue = (row['revenue'] ?? 0).toDouble();
      final expert = (row['netToExpert'] ?? 0).toDouble();

      if (month <= 0) continue;

      revenueSpots.add(FlSpot(month, revenue));
      expertSpots.add(FlSpot(month, expert));

      maxY = [maxY, revenue, expert].reduce((a, b) => a > b ? a : b);
    }

    if (maxY == 0) maxY = 1;

    const primary = Color(0xFF62C6D9);
    const dark = Color(0xFF244C63);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
          const SizedBox(height: 6),
          const Text(
            "Monthly platform revenue compared to expert payouts",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 1,
                maxX: 12,
                maxY: maxY * 1.25,
                borderData: FlBorderData(show: false),
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
                      getTitlesWidget: (v, _) => Text(
                        "\$${v.toInt()}",
                        style: const TextStyle(fontSize: 9),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        const months = [
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
                        final i = v.toInt();
                        if (i < 1 || i > 12) return const SizedBox();
                        return Text(months[i],
                            style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: revenueSpots,
                    isCurved: true,
                    color: primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: expertSpots,
                    isCurved: true,
                    color: dark,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
