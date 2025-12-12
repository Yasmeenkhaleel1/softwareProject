// lib/pages/admin_earnings_page.dart
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminEarningsPage extends StatefulWidget {
  const AdminEarningsPage({super.key});

  @override
  State<AdminEarningsPage> createState() => _AdminEarningsPageState();
}

class _AdminEarningsPageState extends State<AdminEarningsPage> {
  static const baseUrl = "http://localhost:5000";
  static const brand = Color(0xFF62C6D9);

  bool _loading = true;
  bool _loadingTable = false;
  String? _error;

  // Summary
  double totalProcessed = 0;
  double totalNetToExperts = 0;
  double totalPlatformFees = 0;
  double totalRefunds = 0;
  int paymentsCount = 0;
  Map<String, dynamic> statusCounts = {};

  // Charts
  List<dynamic> revenueByDay = [];
  List<dynamic> topExperts = [];
  List<dynamic> statusDistribution = [];

  // Payments table (simple pagination)
  List<dynamic> payments = [];
  int page = 1;
  bool hasMore = true;

  // Filters
  String statusFilter = "ALL";
  DateTimeRange? dateRange;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Map<String, String> _buildQuery() {
    final q = <String, String>{};
    if (statusFilter != "ALL") q['status'] = statusFilter;
    if (dateRange != null) {
      q['from'] = dateRange!.start.toIso8601String();
      q['to'] = dateRange!.end.toIso8601String();
    }
    return q;
  }

  Uri _buildUri(String path, {Map<String, String>? extra}) {
    final query = {..._buildQuery(), if (extra != null) ...extra};
    return Uri.parse("$baseUrl$path").replace(queryParameters: query);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
      page = 1;
      hasMore = true;
      payments = [];
    });

    try {
      await Future.wait([
        _loadSummary(),
        _loadCharts(),
        _loadPayments(reset: true),
      ]);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadSummary() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No admin token found");
    }

    final res = await http.get(
      _buildUri("/api/admin/earnings/summary"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        totalProcessed = (data['totalProcessed'] ?? 0).toDouble();
        totalNetToExperts = (data['totalNetToExperts'] ?? 0).toDouble();
        totalPlatformFees = (data['totalPlatformFees'] ?? 0).toDouble();
        totalRefunds = (data['totalRefunds'] ?? 0).toDouble();
        paymentsCount = data['paymentsCount'] ?? 0;
        statusCounts = Map<String, dynamic>.from(data['statusCounts'] ?? {});
      });
    } else {
      throw Exception("Summary error: ${res.statusCode}");
    }
  }

  Future<void> _loadCharts() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No admin token found");
    }

    final res = await http.get(
      _buildUri("/api/admin/earnings/charts"),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        revenueByDay = data['revenueByDay'] ?? [];
        topExperts = data['topExperts'] ?? [];
        statusDistribution = data['statusDistribution'] ?? [];
      });
    } else {
      throw Exception("Charts error: ${res.statusCode}");
    }
  }

  Future<void> _loadPayments({bool reset = false}) async {
    if (_loadingTable) return;
    if (!reset && !hasMore) return;

    setState(() {
      _loadingTable = true;
      if (reset) {
        page = 1;
        payments = [];
        hasMore = true;
      }
    });

    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception("No admin token found");
    }

    final res = await http.get(
      _buildUri("/api/admin/earnings/payments", extra: {
        'page': page.toString(),
        'limit': '20',
      }),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final items = List<dynamic>.from(data['items'] ?? []);
      final total = (data['total'] ?? 0) as int;
      final pageSize = (data['pageSize'] ?? 20) as int;

      setState(() {
        payments.addAll(items);
        page += 1;
        hasMore = payments.length < total;
      });
    } else {
      throw Exception("Payments error: ${res.statusCode}");
    }

    if (mounted) {
      setState(() => _loadingTable = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = dateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: brand,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => dateRange = picked);
      _loadAll();
    }
  }

  // ======================
  // BUILD (RESPONSIVE)
  // ======================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: brand));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 36),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return isMobile ? _buildMobileView() : _buildWebView();
  }

  // ======================================================
  // 🔒 WEB VIEW — كودك الأصلي بدون أي تغيير
  // ======================================================
  Widget _buildWebView() {
    final bg = Colors.grey.shade100;

    return Container(
      color: bg,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFiltersRow(),
                  const SizedBox(height: 20),
                  _buildSummaryHeaderCard(),
                  const SizedBox(height: 20),
                  _buildSummaryGrid(),
                  const SizedBox(height: 24),
                  _buildChartsSection(),
                  const SizedBox(height: 28),
                  _buildPaymentsHeader(),
                  const SizedBox(height: 8),
                  _buildPaymentsList(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================================================
  // 📱 MOBILE VIEW — تصميم محترف مع كل الميزات
  // ======================================================
  Widget _buildMobileView() {
    return Container(
      color: Colors.grey.shade50,
      child: CustomScrollView(
        slivers: [
          // Header ثابت للموبايل
          SliverAppBar(
            backgroundColor: const Color(0xFF285E6E),
            elevation: 2,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "Earnings Dashboard",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
              background: Container(
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
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filters للموبايل
                  _buildMobileFiltersRow(),
                  const SizedBox(height: 16),
                  
                  // Summary Card للموبايل
                  _buildMobileSummaryCard(),
                  const SizedBox(height: 16),
                  
                  // Stats Grid للموبايل
                  _buildMobileSummaryGrid(),
                  const SizedBox(height: 20),
                  
                  // Charts للموبايل
                  _buildMobileChartsSection(),
                  const SizedBox(height: 20),
                  
                  // Payments Header
                  _buildMobilePaymentsHeader(),
                  const SizedBox(height: 12),
                  
                  // Payments List للموبايل
                  _buildMobilePaymentsList(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ======================
  // MOBILE COMPONENTS
  // ======================
  Widget _buildMobileFiltersRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Filter
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: const [
                DropdownMenuItem(value: "ALL", child: Text("All statuses")),
                DropdownMenuItem(value: "AUTHORIZED", child: Text("Authorized")),
                DropdownMenuItem(value: "CAPTURED", child: Text("Captured")),
                DropdownMenuItem(value: "REFUND_PENDING", child: Text("Refund pending")),
                DropdownMenuItem(value: "REFUNDED", child: Text("Refunded")),
                DropdownMenuItem(value: "FAILED", child: Text("Failed")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => statusFilter = v);
                _loadAll();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Date Range + Actions
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _pickDateRange,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  dateRange == null
                      ? "All time"
                      : "${dateRange!.start.toString().split(' ').first} - ${dateRange!.end.toString().split(' ').first}",
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (dateRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() => dateRange = null);
                  _loadAll();
                },
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                tooltip: "Reset date",
              ),
            ],
            const SizedBox(width: 8),
            IconButton(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh, size: 22),
              tooltip: "Refresh",
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF62C6D9),
            Color(0xFF347C8B),
            Color(0xFF244C63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Total Processed",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "\$${totalProcessed.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payments_outlined, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  "$paymentsCount payments",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSummaryGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildMobileMiniStat(
          title: "Net to Experts",
          value: "\$${totalNetToExperts.toStringAsFixed(2)}",
          icon: Icons.person_outline,
          color: const Color(0xFF00B894),
        ),
        _buildMobileMiniStat(
          title: "Platform Fees",
          value: "\$${totalPlatformFees.toStringAsFixed(2)}",
          icon: Icons.account_balance,
          color: const Color(0xFFE17055),
        ),
        _buildMobileMiniStat(
          title: "Refunded",
          value: "\$${totalRefunds.toStringAsFixed(2)}",
          icon: Icons.undo,
          color: const Color(0xFFD63031),
        ),
        _buildMobileMiniStat(
          title: "Captured",
          value: "${statusCounts['CAPTURED'] ?? 0}",
          icon: Icons.verified,
          color: const Color(0xFF6C5CE7),
        ),
      ],
    );
  }

  Widget _buildMobileMiniStat({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileChartsSection() {
    return Column(
      children: [
        // Revenue Chart
        _buildMobileChartContainer(
          title: "Revenue Timeline",
          subtitle: "Daily total amount processed",
          height: 220,
          child: _buildMobileLineChart(),
        ),
        const SizedBox(height: 16),
        
        // Top Experts Chart
        _buildMobileChartContainer(
          title: "Top Experts",
          subtitle: "Net earnings per expert",
          height: 220,
          child: _buildMobileBarChart(),
        ),
        const SizedBox(height: 16),
        
        // Status Distribution
        _buildMobileChartContainer(
          title: "Payment Status",
          subtitle: "Distribution by status",
          height: 260,
          child: _buildMobilePieChart(),
        ),
      ],
    );
  }

  Widget _buildMobileLineChart() {
    final points = revenueByDay.map<FlSpot>((e) {
      final idx = revenueByDay.indexOf(e).toDouble();
      final total = (e['total'] ?? 0).toDouble();
      return FlSpot(idx, total);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: points,
            isCurved: true,
            barWidth: 2.5,
            color: brand,
            belowBarData: BarAreaData(
              show: true,
              color: brand.withOpacity(0.15),
            ),
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBarChart() {
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < topExperts.length && i < 5; i++) {
      final e = topExperts[i];
      final net = (e['net'] ?? 0).toDouble();
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: net,
              width: 16,
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF347C8B),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final expert = topExperts[groupIndex];
              final name = expert['name']?.toString() ?? 'Expert';
              return BarTooltipItem(
                "$name\n\$${rod.toY.toStringAsFixed(2)}",
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobilePieChart() {
    final totalCount = statusDistribution.fold<int>(
        0, (sum, e) => sum + (e['count'] ?? 0) as int);

    if (totalCount == 0) {
      return const Center(
        child: Text(
          "No payments in this period",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final colors = {
      "AUTHORIZED": Colors.orange,
      "CAPTURED": Colors.green,
      "REFUND_PENDING": Colors.deepOrange,
      "REFUNDED": Colors.redAccent,
      "FAILED": Colors.grey,
    };

    final sections = statusDistribution.map<PieChartSectionData>((e) {
      final st = (e['status'] ?? '').toString();
      final count = (e['count'] ?? 0) as int;
      final color = colors[st] ?? Colors.blueGrey;
      final percentage = ((count / totalCount) * 100).toStringAsFixed(0);

      return PieChartSectionData(
        value: count.toDouble(),
        title: "$percentage%",
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        color: color,
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: statusDistribution.map((e) {
            final st = (e['status'] ?? '').toString();
            final count = (e['count'] ?? 0) as int;
            final color = colors[st] ?? Colors.blueGrey;
            
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${st.replaceAll('_', ' ')}: $count",
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMobileChartContainer({
    required String title,
    required String subtitle,
    required double height,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: Color(0xFF285E6E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildMobilePaymentsHeader() {
    return Row(
      children: [
        const Text(
          "Payments Timeline",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF285E6E),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "$paymentsCount total",
            style: const TextStyle(
              fontSize: 12,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        if (_loadingTable)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildMobilePaymentsList() {
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
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
          children: [
            Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              "No payments in this period",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...payments.map(_buildMobilePaymentTile),
        if (hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ElevatedButton.icon(
              onPressed: () => _loadPayments(reset: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: brand,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: brand),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.expand_more, size: 20),
              label: const Text("Load More"),
            ),
          ),
      ],
    );
  }

  Widget _buildMobilePaymentTile(dynamic p) {
    final amount = (p['amount'] ?? 0).toDouble();
    final net = (p['netToExpert'] ?? 0).toDouble();
    final fee = (p['platformFee'] ?? 0).toDouble();
    final status = (p['status'] ?? '').toString();
    final customer = p['customer'] ?? {};
    final expert = p['expert'] ?? {};
    final service = p['service'] ?? {};

    final customerName = customer['name'] ?? 'Customer';
    final expertName = expert['name'] ?? 'Expert';
    final serviceTitle = service['title'] ?? 'Service';

    // Status styling
    Color statusColor;
    switch (status) {
      case "CAPTURED":
        statusColor = Colors.green;
        break;
      case "AUTHORIZED":
        statusColor = Colors.orange;
        break;
      case "REFUND_PENDING":
        statusColor = Colors.deepOrange;
        break;
      case "REFUNDED":
        statusColor = Colors.redAccent;
        break;
      case "FAILED":
        statusColor = Colors.grey;
        break;
      default:
        statusColor = Colors.blueGrey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.payment,
                  size: 20,
                  color: brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF285E6E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Customer: $customerName",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          
          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Amount",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "\$${amount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Net to Expert",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "\$${net.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00B894),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Platform Fee",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "\$${fee.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE17055),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Expert info
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                "Expert: $expertName",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================
  // WEB COMPONENTS (نفس الكود الأصلي)
  // ======================
  Widget _buildFiltersRow() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: statusFilter,
              items: const [
                DropdownMenuItem(value: "ALL", child: Text("All statuses")),
                DropdownMenuItem(value: "AUTHORIZED", child: Text("Authorized")),
                DropdownMenuItem(value: "CAPTURED", child: Text("Captured")),
                DropdownMenuItem(value: "REFUND_PENDING", child: Text("Refund pending")),
                DropdownMenuItem(value: "REFUNDED", child: Text("Refunded")),
                DropdownMenuItem(value: "FAILED", child: Text("Failed")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => statusFilter = v);
                _loadAll();
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: _pickDateRange,
          icon: const Icon(Icons.date_range),
          label: Text(
            dateRange == null
                ? "All time"
                : "${dateRange!.start.toString().split(' ').first} → ${dateRange!.end.toString().split(' ').first}",
          ),
        ),
        if (dateRange != null)
          TextButton(
            onPressed: () {
              setState(() => dateRange = null);
              _loadAll();
            },
            child: const Text(
              "Reset",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        const Spacer(),
        IconButton(
          onPressed: _loadAll,
          icon: const Icon(Icons.refresh),
          tooltip: "Refresh",
        ),
      ],
    );
  }

  Widget _buildSummaryHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF62C6D9),
            Color(0xFF347C8B),
            Color(0xFF244C63),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Total processed volume",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "\$${totalProcessed.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "$paymentsCount payments in this view",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final crossAxisCount = isWide ? 4 : 2;

        final cards = [
          _miniStatCard(
            title: "Net to experts",
            value: "\$${totalNetToExperts.toStringAsFixed(2)}",
            icon: Icons.person_outline,
            color: Colors.teal,
          ),
          _miniStatCard(
            title: "Platform fees",
            value: "\$${totalPlatformFees.toStringAsFixed(2)}",
            icon: Icons.account_balance,
            color: Colors.deepOrange,
          ),
          _miniStatCard(
            title: "Refunded",
            value: "\$${totalRefunds.toStringAsFixed(2)}",
            icon: Icons.undo,
            color: Colors.redAccent,
          ),
          _miniStatCard(
            title: "Captured payments",
            value: "${statusCounts['CAPTURED'] ?? 0}",
            icon: Icons.verified,
            color: Colors.indigo,
          ),
        ];

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: isWide ? 2.6 : 2.1,
          children: cards,
        );
      },
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildRevenueLineChartCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTopExpertsBarChartCard()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatusPieChartCard()),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildRevenueLineChartCard(),
            const SizedBox(height: 16),
            _buildTopExpertsBarChartCard(),
            const SizedBox(height: 16),
            _buildStatusPieChartCard(),
          ],
        );
      },
    );
  }

  Widget _buildRevenueLineChartCard() {
    final points = revenueByDay.map<FlSpot>((e) {
      final idx = revenueByDay.indexOf(e).toDouble();
      final total = (e['total'] ?? 0).toDouble();
      return FlSpot(idx, total);
    }).toList();

    return _chartContainer(
      title: "Revenue timeline",
      subtitle: "Total amount processed over time",
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
                reservedSize: 0,
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              barWidth: 3,
              color: brand,
              belowBarData: BarAreaData(
                show: true,
                color: brand.withOpacity(0.15),
              ),
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopExpertsBarChartCard() {
    final groups = <BarChartGroupData>[];
    final labels = <String>[];

    for (var i = 0; i < topExperts.length; i++) {
      final e = topExperts[i];
      final net = (e['net'] ?? 0).toDouble();
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: net,
              width: 14,
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFF347C8B),
            ),
          ],
        ),
      );
      labels.add(e['name']?.toString() ?? e['email']?.toString() ?? 'Expert');
    }

    return _chartContainer(
      title: "Top experts by earnings",
      subtitle: "Net earnings per expert",
      child: BarChart(
        BarChartData(
          barGroups: groups,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  final label = labels[idx];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label.length > 8 ? "${label.substring(0, 8)}…" : label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPieChartCard() {
    final totalCount = statusDistribution.fold<int>(
        0, (sum, e) => sum + (e['count'] ?? 0) as int);

    if (totalCount == 0) {
      return _chartContainer(
        title: "Payment status",
        subtitle: "No data for this filter",
        child: const Center(
          child: Text(
            "No payments in this period.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final colors = {
      "AUTHORIZED": Colors.orange,
      "CAPTURED": Colors.green,
      "REFUND_PENDING": Colors.deepOrange,
      "REFUNDED": Colors.redAccent,
      "FAILED": Colors.grey,
    };

    final sections = statusDistribution.map<PieChartSectionData>((e) {
      final st = (e['status'] ?? '').toString();
      final count = (e['count'] ?? 0) as int;
      final value = count.toDouble();
      final color = colors[st] ?? Colors.blueGrey;

      return PieChartSectionData(
        value: value,
        title: "${st.replaceAll('_', ' ')}\n${((count / totalCount) * 100).toStringAsFixed(0)}%",
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        color: color,
      );
    }).toList();

    return _chartContainer(
      title: "Payment status distribution",
      subtitle: "Share of each payment status",
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 32,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  Widget _chartContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF285E6E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPaymentsHeader() {
    return Row(
      children: [
        const Text(
          "Payments timeline",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF285E6E),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blueGrey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            "$paymentsCount total",
            style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
          ),
        ),
        const Spacer(),
        if (_loadingTable)
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildPaymentsList() {
    if (payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "No payments yet for this period.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ...payments.map(_buildPaymentTile),
        if (hasMore)
          TextButton.icon(
            onPressed: () => _loadPayments(reset: false),
            icon: const Icon(Icons.expand_more),
            label: const Text("Load more"),
          ),
      ],
    );
  }

  Widget _buildPaymentTile(dynamic p) {
    final amount = (p['amount'] ?? 0).toDouble();
    final net = (p['netToExpert'] ?? 0).toDouble();
    final fee = (p['platformFee'] ?? 0).toDouble();
    final status = (p['status'] ?? '').toString();
    final createdAt = (p['createdAt'] ?? '').toString();
    final customer = p['customer'] ?? {};
    final expert = p['expert'] ?? {};
    final service = p['service'] ?? {};
    final booking = p['booking'] ?? {};

    final customerName = customer['name'] ?? customer['email'] ?? 'Customer';
    final expertName = expert['name'] ?? expert['email'] ?? 'Expert';
    final serviceTitle = service['title'] ?? 'Service';
    final bookingCode = booking['code'] ?? '';

    Color chipColor;
    String chipText;

    switch (status) {
      case "CAPTURED":
        chipColor = Colors.green;
        chipText = "Captured";
        break;
      case "AUTHORIZED":
        chipColor = Colors.orange;
        chipText = "Authorized";
        break;
      case "REFUND_PENDING":
        chipColor = Colors.deepOrange;
        chipText = "Refund pending";
        break;
      case "REFUNDED":
        chipColor = Colors.redAccent;
        chipText = "Refunded";
        break;
      case "FAILED":
        chipColor = Colors.grey;
        chipText = "Failed";
        break;
      default:
        chipColor = Colors.blueGrey;
        chipText = status;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payment, color: Color(0xFF285E6E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF285E6E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Customer: $customerName  •  Expert: $expertName",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (bookingCode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    "Booking: $bookingCode",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  "\$${amount.toStringAsFixed(2)}  •  Net: \$${net.toStringAsFixed(2)}  •  Fee: \$${fee.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  createdAt,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              chipText,
              style: TextStyle(
                color: chipColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}