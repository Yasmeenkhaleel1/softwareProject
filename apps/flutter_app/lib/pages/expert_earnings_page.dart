import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'dart:async';

enum EarningsFilter {
  all,
  today,
  thisWeek,
  thisMonth,
}

class ExpertEarningsPage extends StatefulWidget {
  const ExpertEarningsPage({super.key});

  @override
  State<ExpertEarningsPage> createState() => _ExpertEarningsPageState();
}

class _ExpertEarningsPageState extends State<ExpertEarningsPage> {
  bool _loading = true;
  String? _error;
  late SharedPreferences _prefs;

  // ✅ إصلاح baseUrl ليعمل على الويب والمحمول
  String get baseUrl {
    if (kIsWeb) {
      // للويب - استخدم localhost أو عنوان الخادم
      return "http://localhost:5000";
    } else {
      // للإميوليتر أو الجهاز الحقيقي
      try {
        // جرب الإميوليتر أولاً
        return "http://10.0.2.2:5000";
      } catch (e) {
        // إذا فشل، جرب localhost
        return "http://localhost:5000";
      }
    }
  }

  EarningsFilter _currentFilter = EarningsFilter.all;
  Map<String, dynamic>? _summary;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _initSharedPrefs();
  }

  Future<void> _initSharedPrefs() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadData();
    } catch (e) {
      setState(() {
        _error = "Failed to initialize: $e";
        _loading = false;
      });
    }
  }

  /// تحديد from/to حسب الفلتر المختار
  Map<String, DateTime?> _rangeForFilter(EarningsFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case EarningsFilter.today:
        final from = DateTime(now.year, now.month, now.day);
        final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return {'from': from, 'to': to};
      case EarningsFilter.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final from = DateTime(monday.year, monday.month, monday.day);
        final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return {'from': from, 'to': to};
      case EarningsFilter.thisMonth:
        final from = DateTime(now.year, now.month, 1);
        final nextMonth = (now.month == 12)
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final to = nextMonth.subtract(const Duration(seconds: 1));
        return {'from': from, 'to': to};
      case EarningsFilter.all:
      default:
        return {'from': null, 'to': null};
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = _prefs.getString('token');
      
      // ✅ إذا لم يوجد token، أظهر رسالة
      if (token == null || token.isEmpty) {
        setState(() {
          _error = "Please login to view earnings";
          _loading = false;
        });
        return;
      }

      final range = _rangeForFilter(_currentFilter);

      final params = <String, String>{};
      if (range['from'] != null) {
        params['from'] = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")
            .format(range['from']!.toUtc());
      }
      if (range['to'] != null) {
        params['to'] = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'")
            .format(range['to']!.toUtc());
      }

      debugPrint("Loading data from: $baseUrl");
      debugPrint("Filter: $_currentFilter");
      debugPrint("Params: $params");

      // ===== SUMMARY =====
      final summaryUri = Uri.parse("$baseUrl/api/expert/earnings/summary")
          .replace(queryParameters: params);

      final summaryRes = await http.get(
        summaryUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("Summary Status: ${summaryRes.statusCode}");
      debugPrint("Summary Body: ${summaryRes.body}");

      if (summaryRes.statusCode >= 400) {
        throw Exception("Failed to load earnings summary: ${summaryRes.statusCode}");
      }

      final summary = jsonDecode(summaryRes.body) as Map<String, dynamic>;

      // ===== PAYMENTS =====
      final paymentsUri = Uri.parse("$baseUrl/api/expert/earnings/payments")
          .replace(queryParameters: params);

      final paymentsRes = await http.get(
        paymentsUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint("Payments Status: ${paymentsRes.statusCode}");

      if (paymentsRes.statusCode >= 400) {
        throw Exception("Failed to load payments: ${paymentsRes.statusCode}");
      }

      final paymentsBody = jsonDecode(paymentsRes.body) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _summary = summary;
        _payments = (paymentsBody['items'] as List<dynamic>?) ?? [];
        _loading = false;
      });

    } on http.ClientException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Network error: ${e.message}\nPlease check if server is running at $baseUrl";
        _loading = false;
      });
      debugPrint("ClientException: $e");
    } on TimeoutException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Request timeout\nServer at $baseUrl is not responding";
        _loading = false;
      });
      debugPrint("TimeoutException: $e");
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error: ${e.toString()}";
        _loading = false;
      });
      debugPrint("Error loading earnings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF62C6D9);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "My Earnings",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primary,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: "Refresh",
          )
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Loading earnings data..."),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62C6D9),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text(
                  "Retry",
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              if (kIsWeb)
                const Text(
                  "Make sure CORS is enabled on your server",
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      );
    }

    final isMobile = MediaQuery.of(context).size.width < 700;
    final s = _summary ?? {};
    final totalRevenue = (s['totalRevenue'] ?? 0).toDouble();
    final totalPlatformFees = (s['totalPlatformFees'] ?? 0).toDouble();
    final totalNetToExpert = (s['totalNetToExpert'] ?? 0).toDouble();
    final bookingsCount = (s['bookingsCount'] ?? 0) as int;
    final paymentsCount = (s['paymentsCount'] ?? 0) as int;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 20,
        ),
        children: [
          _filterChips(),
          SizedBox(height: isMobile ? 16 : 24),
          _headerCard(totalNetToExpert, bookingsCount),
          SizedBox(height: isMobile ? 16 : 24),
          _statsRow(totalRevenue, totalPlatformFees, totalNetToExpert),
          SizedBox(height: isMobile ? 20 : 28),
          _chartsSection(totalRevenue, totalPlatformFees, totalNetToExpert),
          SizedBox(height: isMobile ? 20 : 28),
          const Text(
            "Recent Activity",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF285E6E),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          _timelineSection(),
          SizedBox(height: isMobile ? 20 : 28),
          const Text(
            "Payments History",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF285E6E),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          if (_payments.isEmpty)
            _emptyPaymentsCard()
          else
            ..._payments.map((p) => _paymentTile(p)).toList(),
          SizedBox(height: isMobile ? 20 : 28),
        ],
      ),
    );
  }

  // ------------------ FILTER CHIPS ------------------
  Widget _filterChips() {
    final isMobile = MediaQuery.of(context).size.width < 700;

    Widget chip(EarningsFilter f, String label, IconData icon) {
      final selected = _currentFilter == f;
      return FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: isMobile ? 16 : 18),
            SizedBox(width: isMobile ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        selected: selected,
        selectedColor: const Color(0xFF62C6D9),
        backgroundColor: Colors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? const Color(0xFF62C6D9) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
        ),
        onSelected: (v) {
          if (!v) return;
          setState(() => _currentFilter = f);
          _loadData();
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Wrap(
        spacing: isMobile ? 8 : 12,
        children: [
          chip(EarningsFilter.all, "All Time", Icons.all_inclusive),
          chip(EarningsFilter.today, "Today", Icons.today),
          chip(EarningsFilter.thisWeek, "This Week", Icons.date_range),
          chip(EarningsFilter.thisMonth, "This Month", Icons.calendar_month),
        ],
      ),
    );
  }

  // ------------------ HEADER CARD ------------------
  Widget _headerCard(double netToExpert, int bookingsCount) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: netToExpert),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Container(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              SizedBox(width: isMobile ? 16 : 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Available Balance",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 8),
                    Text(
                      "\$${value.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isMobile ? 32 : 36,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.white70,
                          size: 16,
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Text(
                          "$bookingsCount completed sessions",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------ STATS ROW ------------------
  Widget _statsRow(
    double totalRevenue,
    double totalPlatformFees,
    double netToExpert,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return Column(
        children: [
          _statCard(
            title: "Total Revenue",
            value: totalRevenue,
            icon: Icons.attach_money,
            color: Colors.green,
            subtitle: "From all bookings",
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _statCard(
            title: "Platform Fees",
            value: totalPlatformFees,
            icon: Icons.account_balance,
            color: Colors.orange,
            subtitle: "Service charges",
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _statCard(
            title: "Your Earnings",
            value: netToExpert,
            icon: Icons.person,
            color: Colors.blue,
            subtitle: "After fees",
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: "Total Revenue",
            value: totalRevenue,
            icon: Icons.attach_money,
            color: Colors.green,
            subtitle: "From all bookings",
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: _statCard(
            title: "Platform Fees",
            value: totalPlatformFees,
            icon: Icons.account_balance,
            color: Colors.orange,
            subtitle: "Service charges",
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: _statCard(
            title: "Your Earnings",
            value: netToExpert,
            icon: Icons.person,
            color: Colors.blue,
            subtitle: "After fees",
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    String subtitle = "",
  }) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      builder: (context, animatedValue, child) {
        return Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: isMobile ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: isMobile ? 4 : 6),
                    Text(
                      "\$${animatedValue.toStringAsFixed(2)}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 18 : 20,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------ CHARTS SECTION ------------------
  Widget _chartsSection(
    double totalRevenue,
    double totalPlatformFees,
    double netToExpert,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    final hasData = totalRevenue > 0 || totalPlatformFees > 0 || netToExpert > 0;

    if (!hasData || _payments.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.bar_chart,
              color: Colors.grey.shade400,
              size: 60,
            ),
            SizedBox(height: 12),
            Text(
              "No chart data available",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Complete some bookings to see your earnings analytics",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Earnings Overview",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF285E6E),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              SizedBox(
                height: isMobile ? 200 : 250,
                child: _buildBarChart(totalRevenue, totalPlatformFees, netToExpert),
              ),
            ],
          ),
        ),
        SizedBox(height: isMobile ? 16 : 20),
        Container(
          padding: EdgeInsets.all(isMobile ? 16 : 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Earnings Distribution",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF285E6E),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              SizedBox(
                height: isMobile ? 200 : 250,
                child: _buildPieChart(totalRevenue, totalPlatformFees, netToExpert),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(
    double totalRevenue,
    double totalPlatformFees,
    double netToExpert,
  ) {
    final maxVal = [totalRevenue, totalPlatformFees, netToExpert].reduce(max) * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxVal,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  '\$${value.toInt()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String label;
                switch (value.toInt()) {
                  case 0:
                    label = 'Revenue';
                    break;
                  case 1:
                    label = 'Fees';
                    break;
                  case 2:
                    label = 'Earnings';
                    break;
                  default:
                    label = '';
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  )
                );
            
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        barGroups: [
          BarChartGroupData(
            x: 0,
            barRods: [
              BarChartRodData(
                toY: totalRevenue,
                color: Colors.green.shade400,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          BarChartGroupData(
            x: 1,
            barRods: [
              BarChartRodData(
                toY: totalPlatformFees,
                color: Colors.orange.shade400,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
          BarChartGroupData(
            x: 2,
            barRods: [
              BarChartRodData(
                toY: netToExpert,
                color: Colors.blue.shade400,
                width: 20,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    double totalRevenue,
    double totalPlatformFees,
    double netToExpert,
  ) {
    final total = totalPlatformFees + netToExpert;
    
    if (total <= 0) {
      return const Center(
        child: Text(
          "No distribution data",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final expertPercent = (netToExpert / total) * 100;
    final platformPercent = (totalPlatformFees / total) * 100;

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(
                  value: netToExpert,
                  title: "${expertPercent.toStringAsFixed(0)}%\nYou",
                  radius: 60,
                  color: Colors.blue.shade400,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  titlePositionPercentageOffset: 0.6,
                ),
                PieChartSectionData(
                  value: totalPlatformFees,
                  title: "${platformPercent.toStringAsFixed(0)}%\nPlatform",
                  radius: 50,
                  color: Colors.orange.shade400,
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  titlePositionPercentageOffset: 0.6,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legendItem(
              color: Colors.blue.shade400,
              label: "Your Earnings",
              value: netToExpert,
            ),
            const SizedBox(height: 12),
            _legendItem(
              color: Colors.orange.shade400,
              label: "Platform Fees",
              value: totalPlatformFees,
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required double value,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              "\$${value.toStringAsFixed(2)}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------ TIMELINE SECTION ------------------
  Widget _timelineSection() {
    final isMobile = MediaQuery.of(context).size.width < 700;
    
    if (_payments.isEmpty) {
      return _emptySectionCard(
        icon: Icons.timeline,
        title: "No activity yet",
        message: "Your recent activity will appear here",
      );
    }

    final recentPayments = _payments.take(3).toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: recentPayments.asMap().entries.map((entry) {
          final index = entry.key;
          final p = entry.value;

          final amount = (p['amount'] ?? 0).toDouble();
          final net = (p['netToExpert'] ?? 0).toDouble();
          final status = (p['status'] ?? '').toString();
          final createdAt = _formatDate(p['createdAt']?.toString() ?? '');
          final serviceTitle = p['service']?['title']?.toString() ?? 'Service';

          Color statusColor;
          IconData statusIcon;
          switch (status) {
            case "CAPTURED":
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
              break;
            case "AUTHORIZED":
              statusColor = Colors.orange;
              statusIcon = Icons.pending;
              break;
            case "REFUNDED":
              statusColor = Colors.red;
              statusIcon = Icons.refresh;
              break;
            default:
              statusColor = Colors.grey;
              statusIcon = Icons.circle;
          }

          return Container(
            padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
            decoration: BoxDecoration(
              border: index < recentPayments.length - 1
                  ? Border(
                      bottom: BorderSide(
                        color: Colors.grey.shade200,
                        width: 1,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                SizedBox(width: isMobile ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "\$${net.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ------------------ PAYMENTS LIST ------------------
  Widget _emptyPaymentsCard() {
    return _emptySectionCard(
      icon: Icons.payments,
      title: "No payments yet",
      message: "Your payment history will appear here",
    );
  }

  Widget _emptySectionCard({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.grey.shade400,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentTile(dynamic p) {
    final isMobile = MediaQuery.of(context).size.width < 700;
    
    final amount = (p['amount'] ?? 0).toDouble();
    final net = (p['netToExpert'] ?? 0).toDouble();
    final fee = (p['platformFee'] ?? 0).toDouble();
    final status = (p['status'] ?? '').toString();
    final createdAt = _formatDate(p['createdAt']?.toString() ?? '');
    final serviceTitle = p['service']?['title']?.toString() ?? 'Service Payment';
    final bookingId = p['booking']?['id']?.toString() ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case "CAPTURED":
        statusColor = Colors.green;
        statusText = "Completed";
        statusIcon = Icons.check_circle;
        break;
      case "AUTHORIZED":
        statusColor = Colors.orange;
        statusText = "Pending";
        statusIcon = Icons.pending;
        break;
      case "REFUNDED":
        statusColor = Colors.red;
        statusText = "Refunded";
        statusIcon = Icons.refresh;
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
        statusIcon = Icons.circle;
    }

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                serviceTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF285E6E),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            "Booking #${bookingId.substring(0, min(8, bookingId.length))}",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              _paymentDetailItem(
                icon: Icons.attach_money,
                label: "Total",
                value: "\$${amount.toStringAsFixed(2)}",
                color: Colors.green,
              ),
              SizedBox(width: isMobile ? 16 : 24),
              _paymentDetailItem(
                icon: Icons.account_balance,
                label: "Platform Fee",
                value: "\$${fee.toStringAsFixed(2)}",
                color: Colors.orange,
              ),
              SizedBox(width: isMobile ? 16 : 24),
              _paymentDetailItem(
                icon: Icons.person,
                label: "Your Earnings",
                value: "\$${net.toStringAsFixed(2)}",
                color: Colors.blue,
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: Colors.grey,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                createdAt,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }
}