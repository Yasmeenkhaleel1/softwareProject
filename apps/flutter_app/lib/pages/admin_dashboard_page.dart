// lib/pages/admin_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart'; // للـ Bookings
import 'admin_expert_page.dart';
import 'admin_payments_page.dart';

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
    _tabController = TabController(length: 4, vsync: this);
    _fetchDashboardStats();
    _fetchPendingExperts();
  }

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
        debugPrint("❌ Stats error: ${res.statusCode}");
        setState(() => loadingStats = false);
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching stats: $e");
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
        debugPrint("❌ Pending experts error: ${res.statusCode}");
        setState(() => loadingExperts = false);
      }
    } catch (e) {
      debugPrint("⚠️ Error fetching pending experts: $e");
      setState(() => loadingExperts = false);
    }
  }

  Future<void> _approveExpert(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.patch(
        Uri.parse("$baseUrl/api/admin/experts/$id/approve"),
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
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
        Uri.parse("$baseUrl/api/admin/experts/$id/reject"),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
 appBar: PreferredSize(
  preferredSize: const Size.fromHeight(165), // 🔥 أصغر من 180
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

          // 🔹 Back Button داخل SafeArea
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: Colors.white, size: 24),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // 🔹 العنوان + الأنيميشن
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
                fontSize: 20,    // 🔥 أصغر من 22
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 🔹 Tab Bar
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
            ],
          ),

          const SizedBox(height: 6),
        ],
      ),
    ),
  ),
),



      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMainDashboard(),
          _buildPendingExperts(),
          AdminPaymentsPage(),   // صفحة الدفع
          AdminEarningsPage(),   // صفحة الإيرادات
        ],
      ),
    );
  }

  // =======================
  // 🧮 Main Dashboard (Analytics)
  // =======================
  Widget _buildMainDashboard() {
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
                StatCard(
                    title: "Users",
                    value: "$totalUsers",
                    icon: Icons.people),
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
                  icon: Icons.event_available,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ChartCard(data: monthlyBookings),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: RevenueChartCard(data: revenueByMonth),
                ),
              ],
            ),
            const SizedBox(height: 24),
           
          ],
        ),
      ),
    );
  }

  Widget _headerGradientCard() {
    const primary = Color(0xFF62C6D9);

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
                        fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "LostTreasure is ready for investors.\nYour dashboard looks like a global SaaS.",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
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

  // =======================
  // 👥 Pending Experts Tab
  // =======================
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
        final profileImageUrl = expert['profileImageUrl'] ??
            "http://localhost:5000/uploads/default_profile.png";

        return Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 25,
              backgroundImage: profileImageUrl.startsWith("http")
                  ? NetworkImage(profileImageUrl)
                  : const AssetImage('assets/images/profile_placeholder.png')
                      as ImageProvider,
            ),
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminExpertPage(
                      expertId: expert['_id'],
                    ),
                  ),
                );
              },
              child: Text(
                displayName,
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            subtitle: Text(email),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.check_circle, color: Colors.green),
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
            height: 200,
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
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
          )
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
    // statuses اللي نهتم فيها
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
      child: Row(
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
                    final status = e['status'] as String;
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
                                fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          "$count • ${percent.toStringAsFixed(1)}%",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
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
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
