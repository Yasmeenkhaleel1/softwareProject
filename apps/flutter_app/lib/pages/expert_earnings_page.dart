import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api/api_service.dart';

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

  EarningsFilter _currentFilter = EarningsFilter.all;

  Map<String, dynamic>? _summary;
  List<dynamic> _payments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final range = _rangeForFilter(_currentFilter);
      final s = await ApiService.getExpertEarningsSummary(
        from: range['from'],
        to: range['to'],
      );
      final p = await ApiService.getExpertPayments(
        from: range['from'],
        to: range['to'],
      );

      setState(() {
        _summary = s;
        _payments = p;
      });
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

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF62C6D9);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Earnings"),
        backgroundColor: primary,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          )
        ],
      ),
      backgroundColor: Colors.grey.shade100,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 40),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    final s = _summary ?? {};
    final totalRevenue = (s['totalRevenue'] ?? 0).toDouble();
    final totalPlatformFees = (s['totalPlatformFees'] ?? 0).toDouble();
    final totalNetToExpert = (s['totalNetToExpert'] ?? 0).toDouble();
    final bookingsCount = (s['bookingsCount'] ?? 0) as int;
    final paymentsCount = (s['paymentsCount'] ?? 0) as int;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _filterChips(),
          const SizedBox(height: 16),
          _headerCard(totalNetToExpert, bookingsCount),
          const SizedBox(height: 16),
          _statsRow(totalRevenue, totalPlatformFees, totalNetToExpert, paymentsCount),
          const SizedBox(height: 20),
          _chartsSection(totalRevenue, totalPlatformFees, totalNetToExpert),
          const SizedBox(height: 24),
          const Text(
            "Timeline",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF285E6E),
            ),
          ),
          const SizedBox(height: 8),
          _timelineSection(),
          const SizedBox(height: 24),
          const Text(
            "Payments history",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF285E6E),
            ),
          ),
          const SizedBox(height: 8),
          if (_payments.isEmpty)
            _emptyPaymentsCard()
          else
            ..._payments.map((p) => _paymentTile(p)).toList(),
        ],
      ),
    );
  }

  // ------------------ FILTER CHIPS ------------------
  Widget _filterChips() {
    const primary = Color(0xFF62C6D9);

    Widget chip(EarningsFilter f, String label, IconData icon) {
      final selected = _currentFilter == f;
      return ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        selectedColor: primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w500,
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
      child: Row(
        children: [
          chip(EarningsFilter.all, "All", Icons.all_inclusive),
          const SizedBox(width: 8),
          chip(EarningsFilter.today, "Today", Icons.today),
          const SizedBox(width: 8),
          chip(EarningsFilter.thisWeek, "This week", Icons.date_range),
          const SizedBox(width: 8),
          chip(EarningsFilter.thisMonth, "This month", Icons.calendar_month),
        ],
      ),
    );
  }

  // ------------------ HEADER CARD (Animated Gradient + Numbers) ------------------
  Widget _headerCard(double netToExpert, int bookingsCount) {
    final randomSeed = netToExpert.toInt() + bookingsCount;
    final angle = (randomSeed % 360) * pi / 180;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: netToExpert),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              colors: const [
                Color(0xFF62C6D9),
                Color(0xFF347C8B),
                Color(0xFF244C63),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(angle),
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
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Available earnings",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "\$${value.toStringAsFixed(2)}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$bookingsCount completed sessions",
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
      },
    );
  }

  // ------------------ STATS ROW (Animated Cards) ------------------
  Widget _statsRow(
    double totalRevenue,
    double totalPlatformFees,
    double netToExpert,
    int paymentsCount,
  ) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: "Total revenue",
            value: totalRevenue,
            icon: Icons.attach_money_rounded,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: "Platform fee",
            value: totalPlatformFees,
            icon: Icons.account_balance,
            color: Colors.deepOrange,
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
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      builder: (context, animatedValue, child) {
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
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "\$${animatedValue.toStringAsFixed(2)}",
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
      },
    );
  }

  // ------------------ CHARTS SECTION ------------------
  Widget _chartsSection(
    double totalRevenue,
    double totalPlatformFees,
    double netToExpert,
  ) {
    if (_payments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
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
        child: const Text(
          "No chart data available yet.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return Column(
          children: [
            // Line + Pie
            Flex(
              direction: isWide ? Axis.horizontal : Axis.vertical,
              children: [
                Expanded(
                  flex: 2,
                  child: _lineChartCard(),
                ),
                const SizedBox(width: 12, height: 12),
                Expanded(
                  child: _pieChartCard(totalRevenue, totalPlatformFees, netToExpert),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Bar chart
            _barChartCard(totalRevenue, totalPlatformFees, netToExpert),
          ],
        );
      },
    );
  }

  // Line Chart: cumulative net earnings
  Widget _lineChartCard() {
    // نحضّر البيانات
    double running = 0;
    final spots = <FlSpot>[];
    final paymentsSorted = [..._payments];
    paymentsSorted.sort((a, b) {
      final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.now();
      final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.now();
      return da.compareTo(db);
    });

    for (var i = 0; i < paymentsSorted.length; i++) {
      final p = paymentsSorted[i];
      final net = (p['netToExpert'] ?? 0).toDouble();
      running += net;
      spots.add(FlSpot(i.toDouble(), running));
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Earnings over time",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF285E6E),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, horizontalInterval: spots.length > 0 ? (spots.last.y / 4).clamp(1, double.infinity) : 1),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: Colors.black12),
                    bottom: BorderSide(color: Colors.black12),
                    right: BorderSide(color: Colors.transparent),
                    top: BorderSide(color: Colors.transparent),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (spots.length / 4).clamp(1, double.infinity),
                      getTitlesWidget: (val, meta) {
                        final index = val.toInt();
                        if (index < 0 || index >= paymentsSorted.length) {
                          return const SizedBox.shrink();
                        }
                        final dateStr =
                            (paymentsSorted[index]['createdAt'] ?? '').toString();
                        return Text(
                          dateStr.split('T').first,
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                   belowBarData: BarAreaData(
  show: true,
  color: Colors.blue.withOpacity(0.15),
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

  // Pie Chart: platform vs expert
  Widget _pieChartCard(
      double totalRevenue, double totalPlatformFees, double netToExpert) {
    final total = totalPlatformFees + netToExpert;
    if (total <= 0) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(16),
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
        child: const Center(
          child: Text(
            "No distribution data yet.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final expertPercent = (netToExpert / total) * 100;
    final platformPercent = (totalPlatformFees / total) * 100;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
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
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: netToExpert,
                    title: "${expertPercent.toStringAsFixed(0)}%",
                    radius: 55,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  PieChartSectionData(
                    value: totalPlatformFees,
                    title: "${platformPercent.toStringAsFixed(0)}%",
                    radius: 45,
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendDot(color: Colors.blue, label: "To expert"),
              const SizedBox(height: 4),
              _legendDot(color: Colors.orange, label: "Platform"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Bar chart: comparison of totals
  Widget _barChartCard(
      double totalRevenue, double totalPlatformFees, double netToExpert) {
    if (totalRevenue <= 0 && (totalPlatformFees <= 0 && netToExpert <= 0)) {
      return Container(
        padding: const EdgeInsets.all(16),
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
        child: const Text(
          "No bar chart data yet.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final maxVal =
        [totalRevenue, totalPlatformFees, netToExpert].reduce(max).clamp(1, double.infinity);

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overview",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF285E6E),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: BarChart(
              BarChartData(
                maxY: maxVal.toDouble(),

                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    left: BorderSide(color: Colors.black12),
                    bottom: BorderSide(color: Colors.black12),
                  ),
                ),
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, meta) {
                        switch (val.toInt()) {
                          case 0:
                            return const Text("Revenue", style: TextStyle(fontSize: 10));
                          case 1:
                            return const Text("Platform", style: TextStyle(fontSize: 10));
                          case 2:
                            return const Text("Expert", style: TextStyle(fontSize: 10));
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [BarChartRodData(toY: totalRevenue)],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [BarChartRodData(toY: totalPlatformFees)],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [BarChartRodData(toY: netToExpert)],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------ TIMELINE SECTION ------------------
  Widget _timelineSection() {
    if (_payments.isEmpty) {
      return _emptyPaymentsCard();
    }

    final items = _payments.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final p = entry.value;

          final amount = (p['amount'] ?? 0).toDouble();
          final net = (p['netToExpert'] ?? 0).toDouble();
          final status = (p['status'] ?? '').toString();
          final createdAt = p['createdAt']?.toString() ?? '';

          Color statusColor;
          switch (status) {
            case "CAPTURED":
              statusColor = Colors.green;
              break;
            case "AUTHORIZED":
              statusColor = Colors.orange;
              break;
            case "REFUNDED":
              statusColor = Colors.red;
              break;
            default:
              statusColor = Colors.grey;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الخط + الدائرة
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (index != items.length - 1)
                    Container(
                      width: 2,
                      height: 34,
                      color: Colors.grey.withOpacity(0.3),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "\$${net.toStringAsFixed(2)} to you",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF285E6E),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Total: \$${amount.toStringAsFixed(2)} • Status: $status",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        createdAt,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ------------------ PAYMENTS LIST ------------------
  Widget _emptyPaymentsCard() {
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

  Widget _paymentTile(dynamic p) {
    final amount = (p['amount'] ?? 0).toDouble();
    final net = (p['netToExpert'] ?? 0).toDouble();
    final fee = (p['platformFee'] ?? 0).toDouble();
    final status = (p['status'] ?? '').toString();
    final createdAt = p['createdAt']?.toString() ?? '';
    final serviceTitle =
        p['service']?['title']?.toString() ?? 'Service payment';

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
        chipColor = Colors.red;
        chipText = "Refunded";
        break;
      default:
        chipColor = Colors.grey;
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
              color: const Color(0xFF62C6D9).withOpacity(0.08),
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
                const SizedBox(height: 4),
                Text(
                  "\$${net.toStringAsFixed(2)} to you",
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  "Total: \$${amount.toStringAsFixed(2)}  •  Platform: \$${fee.toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
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
