//lib/pages/admin_dashboard_page
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/stat_card.dart';
import '../widgets/chart_card.dart';
import 'admin_expert_page.dart';

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
  double totalRevenue = 0;
  List<Map<String, dynamic>> monthlyBookings = [];
  List<dynamic> pendingExperts = [];

  static const baseUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchDashboardStats();
    _fetchPendingExperts();
  }

  /// 📊 جلب إحصائيات لوحة التحكم (من الباك)
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
        final cards = data['cards'];
        final charts = data['charts'];

        setState(() {
          totalUsers = cards['totalUsers'] ?? 0;
          totalExperts = cards['totalExperts'] ?? 0;
          totalBookings = cards['totalBookings'] ?? 0;
          totalRevenue = (cards['totalRevenue'] ?? 0).toDouble();
          monthlyBookings =
              List<Map<String, dynamic>>.from(charts['bookingsByMonth'] ?? []);
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

  /// 👤 جلب الخبراء المعلقين (pending)
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

  /// ✅ الموافقة على خبير
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

  /// ❌ رفض خبير (مع إدخال سبب)
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
      backgroundColor: const Color(0xFFF8FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: "Main Dashboard"),
            Tab(icon: Icon(Icons.pending_actions), text: "Pending Experts"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMainDashboard(),
          _buildPendingExperts(),
        ],
      ),
    );
  }

  /// 🧮 القسم الأول: الإحصائيات العامة
  Widget _buildMainDashboard() {
    if (loadingStats) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF62C6D9)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              StatCard(title: "Users", value: "$totalUsers", icon: Icons.people),
              StatCard(title: "Experts", value: "$totalExperts", icon: Icons.engineering),
              StatCard(title: "Bookings", value: "$totalBookings", icon: Icons.event_available),
              StatCard(
                title: "Revenue",
                value: "\$${totalRevenue.toStringAsFixed(2)}",
                icon: Icons.attach_money,
              ),
            ],
          ),
          const SizedBox(height: 30),
          monthlyBookings.isNotEmpty
              ? ChartCard(data: monthlyBookings)
              : const Text(
                  "No monthly data available yet.",
                  style: TextStyle(color: Colors.grey),
                ),
        ],
      ),
    );
  }

  /// 👥 القسم الثاني: قائمة الخبراء المعلقين
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
                    expertId: expert['_id'], // ← أهم تعديل هنا
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
