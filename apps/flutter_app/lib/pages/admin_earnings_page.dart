// lib/pages/admin_earnings_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdminEarningsPage extends StatefulWidget {
  const AdminEarningsPage({super.key});

  @override
  State<AdminEarningsPage> createState() => _AdminEarningsPageState();
}

class _AdminEarningsPageState extends State<AdminEarningsPage> {
  // ==============================
  // ✅ LOGIC (NO CHANGES)
  // ==============================
  String getBaseUrl() {
    if (kIsWeb) {
      return "http://localhost:5000";
    }
    if (Platform.isAndroid) {
      return "http://10.0.2.2:5000";
    } else if (Platform.isIOS) {
      return "http://localhost:5000";
    } else {
      return "http://localhost:5000";
    }
  }

  final Color brand = const Color(0xFF62C6D9);
  final Color darkBlue = const Color(0xFF244C63);
  final Color lightBlue = const Color(0xFF62C6D9);
  final Color mediumBlue = const Color(0xFF347C8B);

  bool _loading = false;
  String? _error;
  bool _demoMode = false;

  double totalProcessed = 0.0;
  double totalNetToExperts = 0.0;
  double totalPlatformFees = 0.0;
  double totalRefunds = 0.0;
  int paymentsCount = 0;

  Map<String, int> statusCounts = {
    'CAPTURED': 0,
    'AUTHORIZED': 0,
    'REFUND_PENDING': 0,
    'REFUNDED': 0,
  };

  List<Map<String, dynamic>> payments = [];
  List<Map<String, dynamic>> filteredPayments = [];

  String statusFilter = "ALL";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final baseUrl = getBaseUrl();
      print('Loading from: $baseUrl');

      final token = await _getToken();
      if (token == null || token.isEmpty) {
        throw Exception("Please login first");
      }

      final summaryResponse = await http.get(
        Uri.parse("$baseUrl/api/admin/earnings/summary"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      print('Summary status: ${summaryResponse.statusCode}');

      if (summaryResponse.statusCode == 200) {
        final data = jsonDecode(summaryResponse.body);
        print('Summary data: $data');

        if (!mounted) return;

        setState(() {
          totalProcessed = (data['totalProcessed'] ?? 0).toDouble();
          totalNetToExperts = (data['totalNetToExperts'] ?? 0).toDouble();
          totalPlatformFees = (data['totalPlatformFees'] ?? 0).toDouble();
          totalRefunds = (data['totalRefunds'] ?? 0).toDouble();
          paymentsCount = data['paymentsCount'] ?? 0;

          if (data['statusCounts'] != null) {
            final counts = Map<String, int>.from(data['statusCounts']);
            statusCounts = {
              'CAPTURED': counts['CAPTURED'] ?? 0,
              'AUTHORIZED': counts['AUTHORIZED'] ?? 0,
              'REFUND_PENDING': counts['REFUND_PENDING'] ?? 0,
              'REFUNDED': counts['REFUNDED'] ?? 0,
            };
          }
          _demoMode = false;
        });

        await _loadPayments(token);
      } else {
        throw Exception("Server error: ${summaryResponse.statusCode}");
      }
    } catch (e) {
      print('Error loading data: $e');

      if (mounted) {
        setState(() {
          _demoMode = true;
          _loadDemoData();
          _error = "Using demo data: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadPayments(String token) async {
    try {
      final baseUrl = getBaseUrl();
      final paymentsResponse = await http.get(
        Uri.parse("$baseUrl/api/admin/earnings/payments"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      print('Payments status: ${paymentsResponse.statusCode}');

      if (paymentsResponse.statusCode == 200) {
        final data = jsonDecode(paymentsResponse.body);
        print('Payments data received, items: ${data['items']?.length ?? 0}');

        if (data['items'] != null && data['items'] is List) {
          final items = List<Map<String, dynamic>>.from(data['items'] as List);

          if (!mounted) return;

          setState(() {
            payments = items;
            filteredPayments = List.from(payments);
            paymentsCount = payments.length;
          });

          print('Loaded ${payments.length} payments');
        } else {
          print('No items in response or wrong format');
          throw Exception('Invalid payments data format');
        }
      } else {
        throw Exception("Payments error: ${paymentsResponse.statusCode}");
      }
    } catch (e) {
      print('Error loading payments: $e');
      _loadDemoPayments();
    }
  }

  Future<String?> _getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      return null;
    }
  }

  void _loadDemoData() {
    setState(() {
      totalProcessed = 12500.75;
      totalNetToExperts = 9500.25;
      totalPlatformFees = 3000.50;
      totalRefunds = 500.00;
      paymentsCount = 47;
      statusCounts = {
        'CAPTURED': 32,
        'AUTHORIZED': 8,
        'REFUND_PENDING': 3,
        'REFUNDED': 4,
      };
    });

    _loadDemoPayments();
  }

  void _loadDemoPayments() {
    final demoPayments = List.generate(20, (index) {
      final statuses = ['CAPTURED', 'AUTHORIZED', 'REFUND_PENDING', 'REFUNDED', 'FAILED'];
      final status = statuses[index % statuses.length];
      final amount = 100.0 + (index * 50.0);
      final customerNames = ['Ahmed Mohamed', 'Sara Khalid', 'Ali Hassan', 'Lina Omar', 'Yousef Samir'];
      final expertNames = ['Website Designer', 'App Developer', 'Marketing Expert', 'Graphic Designer', 'Content Writer'];
      final services = ['Website Design', 'Mobile App', 'Marketing Campaign', 'Logo Design', 'Article Writing'];

      return {
        'id': 'PAY-${1000 + index}',
        'status': status,
        'amount': amount,
        'netToExpert': amount * 0.8,
        'platformFee': amount * 0.2,
        'customer': {'name': customerNames[index % customerNames.length], 'email': 'customer${index + 1}@example.com'},
        'expert': {'name': expertNames[index % expertNames.length], 'email': 'expert${index + 1}@example.com'},
        'service': {'title': services[index % services.length]},
        'booking': {'code': 'BOOK-${2000 + index}'},
        'createdAt': DateTime.now().subtract(Duration(days: index, hours: index * 2)).toIso8601String(),
      };
    });

    setState(() {
      payments = demoPayments;
      filteredPayments = List.from(demoPayments);
      _applyFilters();
    });
  }

  void _applyFilters() {
    if (statusFilter == "ALL") {
      filteredPayments = List.from(payments);
    } else {
      filteredPayments = payments.where((p) => p['status'] == statusFilter).toList();
    }
    if (mounted) setState(() {});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "CAPTURED":
        return const Color(0xFF27AE60);
      case "AUTHORIZED":
        return const Color(0xFFF2994A);
      case "REFUND_PENDING":
        return const Color(0xFFEB5757);
      case "REFUNDED":
        return const Color(0xFFB00020);
      case "FAILED":
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF475569);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case "CAPTURED":
        return "Captured";
      case "AUTHORIZED":
        return "Authorized";
      case "REFUND_PENDING":
        return "Refund Pending";
      case "REFUNDED":
        return "Refunded";
      case "FAILED":
        return "Failed";
      default:
        return status;
    }
  }

  // ==============================
  // ✅ UI (SaaS Redesign)
  // ==============================
  static const Color _pageBg = Color(0xFFF4F7FB);

  @override
  Widget build(BuildContext context) {
    // Keep your existing loading/error behavior (logic untouched)
    if (_loading) return _buildLoadingView();
    if (_error != null && !_demoMode) return _buildErrorView();

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isMobile = w < 900;
        final pad = EdgeInsets.all(isMobile ? 14 : 24);

        return Scaffold(
          backgroundColor: _pageBg,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: pad,
                // ✅ مهم: Slivers = no overflow in constrained heights
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildSaaSHeader(isMobile: isMobile)),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    if (_error != null && _demoMode)
                      SliverToBoxAdapter(
                        child: _InfoBanner(
                          tone: _BannerTone.warning,
                          title: "Demo mode is ON",
                          message: _error!,
                          actionLabel: "Try connect",
                          onAction: _loadData,
                        ),
                      ),

                    if (_error != null && _demoMode) const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    // KPI Grid
                    SliverToBoxAdapter(child: _buildKpiSection(isMobile: isMobile, width: w)),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    // Status pills + Filters
                    SliverToBoxAdapter(child: _buildFiltersSection(isMobile: isMobile)),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    // Payments section header
                    SliverToBoxAdapter(child: _buildPaymentsHeader(isMobile: isMobile)),
                    const SliverToBoxAdapter(child: SizedBox(height: 10)),

                    // Payments Body
                    if (filteredPayments.isEmpty)
                      SliverToBoxAdapter(child: _buildEmptyPayments())
                    else if (isMobile)
                      SliverList.separated(
                        itemCount: filteredPayments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildPaymentCard(filteredPayments[i]),
                      )
                    else
                      SliverToBoxAdapter(
                        child: _SurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: _buildPaymentsTableWeb(),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Header ----------
  Widget _buildSaaSHeader({required bool isMobile}) {
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [lightBlue, mediumBlue, darkBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 44 : 52,
                height: isMobile ? 44 : 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Icon(Icons.trending_up, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Revenue & Earnings",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _demoMode ? "Demo Mode · Sample data for UI testing" : "Live Data · Real-time financial overview",
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(
                          icon: Icons.payments_outlined,
                          label: "$paymentsCount payments",
                          fg: Colors.white,
                          bg: Colors.white.withOpacity(0.16),
                        ),
                        _Pill(
                          icon: Icons.link,
                          label: _demoMode ? "Offline" : "Connected",
                          fg: Colors.white,
                          bg: Colors.white.withOpacity(0.16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  _HeaderButton(
                    label: "Refresh",
                    icon: Icons.refresh,
                    onPressed: _loadData,
                  ),
                  const SizedBox(height: 10),
                  _HeaderButton(
                    label: "Info",
                    icon: Icons.info_outline,
                    onPressed: _showConnectionInfo,
                    outlined: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- KPI Section ----------
  Widget _buildKpiSection({required bool isMobile, required double width}) {
    final kpis = <_KpiData>[
      _KpiData(
        title: "Total Processed",
        value: "\$${totalProcessed.toStringAsFixed(2)}",
        hint: "All successful transactions",
        icon: Icons.attach_money,
        color: const Color(0xFF4C6FFF),
      ),
      _KpiData(
        title: "Net to Experts",
        value: "\$${totalNetToExperts.toStringAsFixed(2)}",
        hint: "Transferred to experts",
        icon: Icons.people_outline,
        color: const Color(0xFF27AE60),
      ),
      _KpiData(
        title: "Platform Fees",
        value: "\$${totalPlatformFees.toStringAsFixed(2)}",
        hint: "Platform commission",
        icon: Icons.account_balance_outlined,
        color: const Color(0xFFF2994A),
      ),
      _KpiData(
        title: "Refunded",
        value: "\$${totalRefunds.toStringAsFixed(2)}",
        hint: "Total refunded amount",
        icon: Icons.reply_outlined,
        color: const Color(0xFFEB5757),
      ),
    ];

    final cols = isMobile ? 2 : (width >= 1180 ? 4 : 3);
    final itemW = isMobile ? 1.0 : 1.0;

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Overview",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF244C63)),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isMobile ? 1.35 : 2.25,
            children: [
              for (final k in kpis) _KpiCard(data: k, widthFactor: itemW),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Filters ----------
  Widget _buildFiltersSection({required bool isMobile}) {
    final captured = statusCounts['CAPTURED'] ?? 0;
    final authorized = statusCounts['AUTHORIZED'] ?? 0;
    final refundPending = statusCounts['REFUND_PENDING'] ?? 0;
    final refunded = statusCounts['REFUNDED'] ?? 0;

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filters & Status",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Color(0xFF244C63)),
          ),
          const SizedBox(height: 10),

          // status pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatusPill(text: "Captured: $captured", color: _getStatusColor("CAPTURED")),
                const SizedBox(width: 8),
                _StatusPill(text: "Authorized: $authorized", color: _getStatusColor("AUTHORIZED")),
                const SizedBox(width: 8),
                _StatusPill(text: "Refund Pending: $refundPending", color: _getStatusColor("REFUND_PENDING")),
                const SizedBox(width: 8),
                _StatusPill(text: "Refunded: $refunded", color: _getStatusColor("REFUNDED")),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // filters row
          isMobile
              ? Column(
                  children: [
                    _buildStatusDropdown(),
                    const SizedBox(height: 10),
                    _buildSearchField(),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 320, child: _buildStatusDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSearchField()),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<String>(
      value: statusFilter,
      decoration: InputDecoration(
        labelText: "Payment Status",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(value: "ALL", child: Text("All Statuses")),
        DropdownMenuItem(value: "CAPTURED", child: Text("Captured")),
        DropdownMenuItem(value: "AUTHORIZED", child: Text("Authorized")),
        DropdownMenuItem(value: "REFUND_PENDING", child: Text("Refund Pending")),
        DropdownMenuItem(value: "REFUNDED", child: Text("Refunded")),
        DropdownMenuItem(value: "FAILED", child: Text("Failed")),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() {
            statusFilter = value;
            _applyFilters();
          });
        }
      },
    );
  }

  Widget _buildSearchField() {
    // UI only (logic same: search not implemented before)
    return TextField(
      decoration: InputDecoration(
        hintText: "Search by customer, expert, or service…",
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (value) {
        // Search functionality can be added here (kept as before: no logic)
      },
    );
  }

  // ---------- Payments Header ----------
  Widget _buildPaymentsHeader({required bool isMobile}) {
    return Row(
      children: [
        const Text(
          "Payments History",
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: Color(0xFF244C63)),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF244C63).withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF244C63).withOpacity(0.12)),
          ),
          child: Text(
            "${filteredPayments.length} payments",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF244C63)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPayments() {
    return _SurfaceCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.payments_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          const Text(
            "No payments found",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            "Try changing filters",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ---------- Web Table ----------
  Widget _buildPaymentsTableWeb() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Latest payments",
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF244C63)),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 980),
            child: DataTable(
              headingRowHeight: 46,
              dataRowMinHeight: 58,
              dataRowMaxHeight: 64,
              columnSpacing: 22,
              horizontalMargin: 14,
              headingTextStyle: const TextStyle(fontWeight: FontWeight.w900),
              columns: const [
                DataColumn(label: Text("Service")),
                DataColumn(label: Text("Customer")),
                DataColumn(label: Text("Expert")),
                DataColumn(label: Text("Amount")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Date")),
              ],
              // ✅ Keep same behavior: you were showing take(10)
              rows: filteredPayments.take(10).map((payment) {
                final status = payment['status'] as String;
                final serviceTitle = (payment['service'] is Map) ? (payment['service']['title'] ?? 'Service') : 'Service';

                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 240,
                        child: Text(serviceTitle.toString(), overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DataCell(Text((payment['customer'] is Map) ? (payment['customer']['name'] ?? 'Customer') : 'Customer')),
                    DataCell(Text((payment['expert'] is Map) ? (payment['expert']['name'] ?? 'Expert') : 'Expert')),
                    DataCell(
                      Text(
                        "\$${(payment['amount'] ?? 0).toStringAsFixed(2)}",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    DataCell(_StatusChip(label: _getStatusText(status), color: _getStatusColor(status))),
                    DataCell(Text((payment['createdAt'] as String).substring(0, 10))),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ======================
  // OLD VIEWS (logic kept)
  // ======================
  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _SurfaceCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 56),
                const SizedBox(height: 12),
                Text(
                  _error ?? "An error occurred",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, color: Colors.red, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Try Again"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: _pageBg,
      body: Center(
        child: _SurfaceCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: brand),
              const SizedBox(height: 14),
              const Text(
                "Loading data...",
                style: TextStyle(fontSize: 14.5, color: Colors.grey, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================
  // Existing Payment Card (kept)
  // ======================
  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status'] as String;
    final amount = (payment['amount'] ?? 0).toDouble();
    final customer = payment['customer'] as Map<String, dynamic>;
    final expert = payment['expert'] as Map<String, dynamic>;
    final service = payment['service'] as Map<String, dynamic>;
    final createdAt = payment['createdAt'] as String;

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.payment, color: _getStatusColor(status), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service['title'] ?? 'Service',
                      style: const TextStyle(
                        fontSize: 14.8,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF244C63),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customer['name'] ?? 'Customer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: _getStatusText(status), color: _getStatusColor(status)),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _KeyValue(
                  k: "Amount",
                  v: "\$${amount.toStringAsFixed(2)}",
                  strong: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KeyValue(
                  k: "Expert",
                  v: (expert['name'] ?? 'Expert').toString(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _KeyValue(
                  k: "Date",
                  v: createdAt.substring(0, 10),
                ),
              ),
              if (status == "CAPTURED")
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.25)),
                  ),
                  child: const Text(
                    "Successful",
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF27AE60), fontWeight: FontWeight.w900),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ======================
  // Connection Info Dialog (logic same)
  // ======================
  void _showConnectionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Connection Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_demoMode ? "🟡 Demo Mode" : "🟢 Connected to Server"),
            const SizedBox(height: 12),
            Text("Server: ${getBaseUrl()}"),
            const SizedBox(height: 8),
            Text("Payments Count: ${filteredPayments.length}"),
            const SizedBox(height: 8),
            Text("Last Updated: ${DateTime.now().toString().substring(0, 16)}"),
            if (_demoMode) ...[
              const SizedBox(height: 12),
              const Text(
                "💡 Note: Displaying demo data. To connect to real server:",
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                "1. Make sure server is running\n2. Put computer IP in getBaseUrl() function\n3. Make sure both devices are on same network",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
          if (_demoMode)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _loadData();
              },
              child: const Text("Try Connect"),
            ),
        ],
      ),
    );
  }
}

/*────────────────────────  UI Components  ────────────────────────*/

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({required this.child, this.padding = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withOpacity(0.7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF244C63),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          );

    final btn = outlined
        ? OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: style)
        : ElevatedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label), style: style);

    return SizedBox(width: 122, child: btn);
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  const _Pill({required this.icon, required this.label, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String k;
  final String v;
  final bool strong;

  const _KeyValue({required this.k, required this.v, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          k,
          style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF244C63),
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
            fontSize: strong ? 16 : 13.5,
          ),
        ),
      ],
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;

  _KpiData({
    required this.title,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final double widthFactor;

  const _KpiCard({required this.data, required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: const [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  data.value,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF244C63)),
                ),
                const SizedBox(height: 4),
                Text(
                  data.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _BannerTone { warning }

class _InfoBanner extends StatelessWidget {
  final _BannerTone tone;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoBanner({
    required this.tone,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final Color c = const Color(0xFFF2994A);
    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.warning_amber_rounded, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF244C63))),
                const SizedBox(height: 4),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: c,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]
        ],
      ),
    );
  }
}
