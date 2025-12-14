// lib/pages/admin_payments_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AdminPaymentsPage extends StatefulWidget {
  const AdminPaymentsPage({super.key});

  @override
  State<AdminPaymentsPage> createState() => _AdminPaymentsPageState();
}

class _AdminPaymentsPageState extends State<AdminPaymentsPage> {
  // ✅ دالة ديناميكية للحصول على baseUrl بناءً على المنصة
String getBaseUrl() {
  if (kIsWeb) {
    // Web
    return "http://localhost:5000";
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return "http://10.0.2.2:5000";
    case TargetPlatform.iOS:
      return "http://localhost:5000";
    default:
      return "http://localhost:5000";
  }
}

  bool _loading = true;
  String? _error;

  List<dynamic> _payments = [];
  List<dynamic> _filteredPayments = [];

  String _statusFilter = "ALL";
  DateTimeRange? _dateRange;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  // ============================
  // 🔄 Fetch + Filters
  // ============================

  Future<void> _fetchPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl(); // ✅ استخدام الدالة الديناميكية

      final res = await http.get(
        Uri.parse("$baseUrl/api/admin/payments"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _payments = data['items'] ?? [];
        _applyFilters();
      } else {
        _error = "Error: ${res.statusCode}";
        debugPrint("📡 Base URL: $baseUrl");
      }
    } catch (e) {
      _error = e.toString();
      debugPrint("🔍 تأكد أن السيرفر يعمل على ${getBaseUrl()}");
    }

    setState(() => _loading = false);
  }

  void _applyFilters() {
    List<dynamic> list = List<dynamic>.from(_payments);

    // ✅ Filter by status
    if (_statusFilter != "ALL") {
      list = list.where((p) => (p['status'] ?? "") == _statusFilter).toList();
    }

    // ✅ Filter by date range (createdAt)
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23,
        59,
        59,
      );

      list = list.where((p) {
        final createdAt = _parseDate(p['createdAt']);
        if (createdAt == null) return false;
        return createdAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            createdAt.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }

    // ✅ Search (ID / customer / expert / service)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final id = (p['_id'] ?? '').toString().toLowerCase();
        final cust = (p['customer']?['email'] ?? '').toString().toLowerCase();
        final expert = (p['expert']?['email'] ?? '').toString().toLowerCase();
        final service = (p['service']?['title'] ?? '').toString().toLowerCase();
        return id.contains(q) ||
            cust.contains(q) ||
            expert.contains(q) ||
            service.contains(q);
      }).toList();
    }

    setState(() {
      _filteredPayments = list;
    });
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initial = _dateRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF62C6D9),
              onPrimary: Colors.white,
              onSurface: Color(0xFF244C63),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateRange = picked;
      });
      _applyFilters();
    }
  }

  // ============================
  // 💸 Refund
  // ============================

  Future<void> _refundPayment(dynamic p) async {
    final amount = (p['amount'] ?? 0).toDouble();
    final amountController =
        TextEditingController(text: amount.toStringAsFixed(2));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Refund Payment",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Payment ID: ${p['_id']}",
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 4),
            Text("Status: ${p['status']}",
                style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 10),
            Text(
              "Max refundable: \$${amount.toStringAsFixed(2)}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF244C63),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: "Refund Amount (USD)",
                helperText:
                    "Leave the same amount for a full refund. Change it for partial refund.",
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.reply, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(context, true),
            label: const Text("Confirm Refund"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl(); // ✅ استخدام الدالة الديناميكية
      final parsedAmount = double.tryParse(amountController.text.trim());

      final res = await http.post(
        Uri.parse("$baseUrl/api/payments/refund"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "paymentId": p['_id'],
          if (parsedAmount != null) "amount": parsedAmount,
        }),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Refund requested (Stripe will handle).")),
        );
        _fetchPayments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: ${res.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // ============================
  // 🧾 Payment Details & Timeline
  // ============================

  void _showPaymentDetails(dynamic p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        return _PaymentDetailsSheet(
          payment: p,
          onRefund: () {
            Navigator.pop(context);
            _refundPayment(p);
          },
          isMobile: isMobile,
        );
      },
    );
  }

  // ============================
  // 🎨 UI - MAIN BUILD
  // ============================

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF62C6D9)),
            )
          : _error != null
              ? _buildError()
              : isMobile
                  ? _buildMobileView()
                  : _buildWebView(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _fetchPayments,
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  // ============================
  // 📱 MOBILE VIEW
  // ============================
  Widget _buildMobileView() {
    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            backgroundColor: const Color(0xFF285E6E),
            expandedHeight: 180, // Increased height to accommodate stats
            floating: false,
            pinned: true,
            centerTitle: true,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
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
                    child: Padding(
                      padding: const EdgeInsets.only(top: 70, left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Payments & Refunds",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Monitor payments and refunds in real-time",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                       
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
SliverToBoxAdapter(
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: _buildMobileStatsSummary(),
  ),
),

          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildMobileFilters(),
            ),
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildMobileStatCards(),
            ),
          ),

          // Payments List
          if (_filteredPayments.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.payments_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "No payments found",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _statusFilter != "ALL"
                          ? "Try changing the status filter"
                          : "Try adjusting your search or date range",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final payment = _filteredPayments[index];
                  return _buildMobilePaymentCard(payment);
                },
                childCount: _filteredPayments.length,
              ),
            ),
        ],
      ),
    );
  }


Widget _buildMobileStatsSummary() {
  final captured =
      _filteredPayments.where((p) => (p['status'] ?? "") == "CAPTURED").length;

  double totalVolume = 0;
  for (final p in _filteredPayments) {
    final raw = p['amount'];
    if (raw is num) {
      totalVolume += raw.toDouble();
    } else if (raw is String) {
      totalVolume += double.tryParse(raw) ?? 0;
    }
  }

  return Row(
    children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF347C8B), // ✅ صار واضح
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "\$${totalVolume.toStringAsFixed(0)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Total Volume",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF244C63), // ✅
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "$captured",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Captured",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
   Widget? _buildMobileFilters() {
return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Filters",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Color(0xFF244C63),
              ),
            ),
            const SizedBox(height: 12),

            // Status Filter
            DropdownButtonFormField<String>(
              initialValue: _statusFilter,
              decoration: InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              items: const [
                DropdownMenuItem(value: "ALL", child: Text("All Statuses")),
                DropdownMenuItem(value: "CAPTURED", child: Text("Captured")),
                DropdownMenuItem(value: "AUTHORIZED", child: Text("Authorized")),
                DropdownMenuItem(value: "REFUNDED", child: Text("Refunded")),
                DropdownMenuItem(value: "REFUND_PENDING", child: Text("Refund Pending")),
                DropdownMenuItem(value: "FAILED", child: Text("Failed")),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _statusFilter = v);
                _applyFilters();
              },
            ),

            const SizedBox(height: 12),

            // Date Range
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _pickDateRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _dateRange == null
                      ? "Select Date Range"
                      : "${_dateRange!.start.toString().split(' ').first} - ${_dateRange!.end.toString().split(' ').first}",
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Search
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: "Search payments...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
            ),

            if (_dateRange != null || _statusFilter != "ALL" || _searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _statusFilter = "ALL";
                        _dateRange = null;
                        _searchQuery = "";
                      });
                      _applyFilters();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text("Clear Filters"),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    
   
  }

  Widget _buildMobileStatCards() {
    final captured = _filteredPayments.where((p) => p['status'] == "CAPTURED").length;
    final authorized = _filteredPayments.where((p) => p['status'] == "AUTHORIZED").length;
    final refunded = _filteredPayments.where((p) => p['status'] == "REFUNDED").length;
    final refundPending = _filteredPayments.where((p) => p['status'] == "REFUND_PENDING").length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildMobileStatCard("Captured", "$captured", Colors.green, Icons.check_circle),
          const SizedBox(width: 12),
          _buildMobileStatCard("Authorized", "$authorized", Colors.orange, Icons.lock_open),
          const SizedBox(width: 12),
          _buildMobileStatCard("Refunded", "$refunded", Colors.redAccent, Icons.reply),
          const SizedBox(width: 12),
          _buildMobileStatCard("Pending", "$refundPending", Colors.blueGrey, Icons.hourglass_bottom),
        ],
      ),
    );
  }

  Widget _buildMobileStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      width: 140,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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

  Widget _buildMobilePaymentCard(dynamic p) {
    final amount = (p['amount'] ?? 0).toDouble();
    final status = p['status'] ?? "";
    final customer = p['customer']?['email'] ?? "Unknown";
    final expert = p['expert']?['email'] ?? "Unknown";
    final service = p['service']?['title'] ?? "Service";
    final createdAt = p['createdAt']?.toString().substring(0, 10) ?? "";

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        onTap: () => _showPaymentDetails(p),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: _statusColor(status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF244C63),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Amount",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "\$${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF244C63),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Customer",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        child: Text(
                          customer,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Expert & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Expert",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expert,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (status == "CAPTURED")
                    ElevatedButton(
                      onPressed: () => _refundPayment(p),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.1),
                        foregroundColor: Colors.redAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
                        ),
                      ),
                      child: const Text("Refund"),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================
  // 🖥️ WEB VIEW
  // ============================
  Widget _buildWebView() {
    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1100;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildFilterBar(),
                const SizedBox(height: 18),
                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildStatCards()),
                      const SizedBox(width: 18),
                      Expanded(flex: 3, child: _buildChartsSection()),
                    ],
                  )
                else ...[
                  _buildStatCards(),
                  const SizedBox(height: 18),
                  _buildChartsSection(),
                ],
                const SizedBox(height: 20),
                _buildPaymentsTable(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================
  // 🎨 WEB COMPONENTS
  // ============================
  Widget _buildHeader() {
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
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "Payments & Refunds",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Monitor captured payments, pending refunds and transaction history in real-time.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  "Tip: Click any payment row to view its full timeline and details.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Container(
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white24),
              ),
              padding: const EdgeInsets.all(14),
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Escrow Mode Enabled\n\n"
                  "Refunds are processed via Stripe. "
                  "Platform controls WHEN to capture or refund.",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final statuses = [
      "ALL",
      "AUTHORIZED",
      "CAPTURED",
      "REFUND_PENDING",
      "REFUNDED",
      "FAILED",
    ];

    String dateLabel;
    if (_dateRange == null) {
      dateLabel = "All dates";
    } else {
      final s = _dateRange!.start;
      final e = _dateRange!.end;
      dateLabel =
          "${s.year}/${s.month.toString().padLeft(2, '0')}/${s.day.toString().padLeft(2, '0')} - "
          "${e.year}/${e.month.toString().padLeft(2, '0')}/${e.day.toString().padLeft(2, '0')}";
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Status filter
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: const InputDecoration(
                  labelText: "Status",
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: statuses
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _statusFilter = v;
                  });
                  _applyFilters();
                },
              ),
            ),

            // Date range
            SizedBox(
              width: 220,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  side: const BorderSide(color: Color(0xFF62C6D9)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.date_range, size: 18),
                onPressed: _pickDateRange,
                label: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    dateLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),

            // Search
            SizedBox(
              width: 260,
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelText: "Search (ID / customer / expert / service)",
                ),
                onChanged: (val) {
                  _searchQuery = val;
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    final captured =
        _filteredPayments.where((p) => p['status'] == "CAPTURED").length;
    final authorized =
        _filteredPayments.where((p) => p['status'] == "AUTHORIZED").length;
    final refunded =
        _filteredPayments.where((p) => p['status'] == "REFUNDED").length;
    final refundPending =
        _filteredPayments.where((p) => p['status'] == "REFUND_PENDING").length;

    double totalVolume = 0;
    for (final p in _filteredPayments) {
      totalVolume += (p['amount'] ?? 0).toDouble();
    }

    Widget card(String title, String subtitle, String value, Color color,
        IconData icon) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.12),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF244C63),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: card(
                "Total Volume",
                "Sum of all payments (filtered)",
                "\$${totalVolume.toStringAsFixed(2)}",
                const Color(0xFF62C6D9),
                Icons.payments,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: card("Captured", "Successfully captured payments",
                  "$captured", Colors.green, Icons.check_circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: card("Authorized", "Authorized but not captured yet",
                  "$authorized", Colors.orange, Icons.lock_open),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: card("Refunded", "Completed refunds", "$refunded",
                  Colors.redAccent, Icons.reply),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: card("Refund Pending", "Awaiting Stripe completion",
                  "$refundPending", Colors.blueGrey, Icons.hourglass_bottom),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartsSection() {
    if (_filteredPayments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Text(
          "No payments found for the current filters.",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildRevenueLineChart()),
            const SizedBox(width: 16),
            SizedBox(width: 260, child: _buildStatusPieChart()),
          ],
        ),
      ],
    );
  }

  Widget _buildRevenueLineChart() {
    final Map<String, double> byDate = {};
    for (final p in _filteredPayments) {
      final dt = _parseDate(p['createdAt']);
      if (dt == null) continue;
      final key =
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      byDate[key] = (byDate[key] ?? 0) + (p['amount'] ?? 0).toDouble();
    }

    final keys = byDate.keys.toList()..sort();
    if (keys.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Text(
          "No revenue data.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final spots = <FlSpot>[];
    double maxY = 0;
    for (int i = 0; i < keys.length; i++) {
      final v = byDate[keys[i]] ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
      if (v > maxY) maxY = v;
    }
    if (maxY == 0) maxY = 1;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Revenue Trend",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Daily revenue based on filtered payments.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (keys.length - 1).toDouble(),
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
                      reservedSize: 40,
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
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= keys.length) {
                          return const SizedBox();
                        }
                        final label = keys[idx].substring(5);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 8),
                          ),
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
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF62C6D9),
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF62C6D9).withOpacity(0.25),
                          const Color(0xFF62C6D9).withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
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

  Widget _buildStatusPieChart() {
    final Map<String, int> counts = {};
    for (final p in _filteredPayments) {
      final st = (p['status'] ?? "UNKNOWN").toString();
      counts[st] = (counts[st] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Text(
          "No status data.",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final statuses = counts.keys.toList();
    final colors = [
      const Color(0xFF62C6D9),
      const Color(0xFF347C8B),
      const Color(0xFF244C63),
      Colors.orangeAccent,
      Colors.redAccent,
      Colors.blueGrey,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Status Breakdown",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Distribution of payment statuses.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 38,
                sections: List.generate(statuses.length, (i) {
                  final s = statuses[i];
                  final c = counts[s] ?? 0;
                  final pct = ((c / total) * 100);
                  return PieChartSectionData(
                    value: c.toDouble(),
                    color: colors[i % colors.length],
                    radius: 60,
                    title: "${pct.toStringAsFixed(1)}%",
                    titleStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (int i = 0; i < statuses.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
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
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          statuses[i],
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        "${counts[statuses[i]]} trx",
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTable() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Payments Table",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1F2933),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Click any row to view full payment details and timeline.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 44,
              dataRowHeight: 60,
              columnSpacing: 28,
              columns: const [
                DataColumn(label: Text("ID")),
                DataColumn(label: Text("Status")),
                DataColumn(label: Text("Customer")),
                DataColumn(label: Text("Expert")),
                DataColumn(label: Text("Service")),
                DataColumn(label: Text("Amount")),
                DataColumn(label: Text("Net to Expert")),
                DataColumn(label: Text("Created At")),
                DataColumn(label: Text("Actions")),
              ],
              rows: _filteredPayments.map((p) => _row(p)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _row(dynamic p) {
    final status = p['status'] ?? "";
    final amount = (p['amount'] ?? 0).toDouble();
    final netToExpert = (p['netToExpert'] ?? 0).toDouble();

    return DataRow(
      onSelectChanged: (_) => _showPaymentDetails(p),
      cells: [
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              p['_id'] ?? "",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        DataCell(_statusChip(status, _statusColor(status))),
        DataCell(
          Text(
            p['customer']?['email'] ?? "",
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          Text(
            p['expert']?['email'] ?? "",
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              p['service']?['title'] ?? "-",
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        DataCell(
          Text(
            "\$${amount.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          Text(
            "\$${netToExpert.toStringAsFixed(2)}",
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          Text(
            p['createdAt']?.toString().substring(0, 19) ?? "",
            style: const TextStyle(fontSize: 10),
          ),
        ),
        DataCell(
          status == "CAPTURED"
              ? TextButton.icon(
                  onPressed: () => _refundPayment(p),
                  icon:
                      const Icon(Icons.reply, size: 18, color: Colors.redAccent),
                  label: const Text(
                    "Refund",
                    style: TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "CAPTURED":
        return Colors.green;
      case "AUTHORIZED":
        return Colors.orange;
      case "REFUNDED":
        return Colors.redAccent;
      case "REFUND_PENDING":
        return Colors.deepOrange;
      case "FAILED":
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ============================
// 🧾 PAYMENT DETAILS SHEET (Mobile Optimized)
// ============================
class _PaymentDetailsSheet extends StatelessWidget {
  final dynamic payment;
  final VoidCallback onRefund;
  final bool isMobile;

  const _PaymentDetailsSheet({
    required this.payment,
    required this.onRefund,
    required this.isMobile,
  });

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "CAPTURED":
        return Colors.green;
      case "AUTHORIZED":
        return Colors.orange;
      case "REFUNDED":
        return Colors.redAccent;
      case "REFUND_PENDING":
        return Colors.deepOrange;
      case "FAILED":
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] ?? 0).toDouble();
    final net = (payment['netToExpert'] ?? 0).toDouble();
    final platform = (payment['platformFee'] ?? 0).toDouble();
    final refundedAmount = (payment['refundedAmount'] ?? 0).toDouble();

    final timelineRaw = (payment['timeline'] ?? []) as List<dynamic>;
    final timeline = timelineRaw.map((e) => e as Map<String, dynamic>).toList();
    timeline.sort((a, b) {
      final ad = _parseDate(a['at']);
      final bd = _parseDate(b['at']);
      if (ad == null || bd == null) return 0;
      return bd.compareTo(ad);
    });

    return DraggableScrollableSheet(
      initialChildSize: isMobile ? 0.85 : 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: Colors.white,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Color(0xFF62C6D9)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "Payment Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF244C63),
                        ),
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _statusColor(payment['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        payment['status'] ?? "",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(payment['status']),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Payment ID
                Text(
                  "Payment ID: ${payment['_id']}",
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),

                const SizedBox(height: 16),

                // Amount Cards
                if (isMobile)
                  _buildMobileAmountCards(amount, net, platform, refundedAmount)
                else
                  _buildWebAmountPills(amount, net, platform, refundedAmount),

                const SizedBox(height: 16),

                // Customer & Expert
                if (isMobile)
                  _buildMobileUserInfo(payment)
                else
                  _buildWebUserInfo(payment),

                const SizedBox(height: 16),

                // Service & Booking
                if (payment['service']?['title'] != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Service: ${payment['service']?['title']}",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),

                if (payment['booking']?['code'] != null)
                  Text(
                    "Booking Code: ${payment['booking']?['code']}",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),

                const SizedBox(height: 20),

                // Timeline Header
                const Text(
                  "Payment Timeline",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF244C63),
                  ),
                ),

                const SizedBox(height: 12),

                // Timeline
                if (timeline.isEmpty)
                  const Text(
                    "No timeline entries yet.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < timeline.length; i++)
                        _buildTimelineItem(timeline[i],
                            isLast: i == timeline.length - 1),
                    ],
                  ),

                const SizedBox(height: 24),

                // Refund Button
                if ((payment['status'] ?? '') == "CAPTURED")
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 20,
                          vertical: isMobile ? 12 : 10,
                        ),
                      ),
                      onPressed: onRefund,
                      icon: const Icon(Icons.reply, size: 18),
                      label: Text(
                        "Refund Payment",
                        style: TextStyle(fontSize: isMobile ? 14 : 13),
                      ),
                    ),
                  ),

                SizedBox(height: isMobile ? 40 : 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileAmountCards(
      double amount, double net, double platform, double refunded) {
    return Column(
      children: [
        _buildMobileAmountCard(
            "Amount", "\$${amount.toStringAsFixed(2)}", Colors.blue),
        const SizedBox(height: 8),
        _buildMobileAmountCard(
            "Net to Expert", "\$${net.toStringAsFixed(2)}", Colors.green),
        const SizedBox(height: 8),
        _buildMobileAmountCard(
            "Platform Fee", "\$${platform.toStringAsFixed(2)}", Colors.orange),
        const SizedBox(height: 8),
        _buildMobileAmountCard(
            "Refunded", "\$${refunded.toStringAsFixed(2)}", Colors.red),
      ],
    );
  }

  Widget _buildMobileAmountCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebAmountPills(
      double amount, double net, double platform, double refunded) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildAmountPill("Amount", "\$${amount.toStringAsFixed(2)}", Colors.blue),
        _buildAmountPill(
            "Net to Expert", "\$${net.toStringAsFixed(2)}", Colors.green),
        _buildAmountPill(
            "Platform Fee", "\$${platform.toStringAsFixed(2)}", Colors.orange),
        _buildAmountPill(
            "Refunded", "\$${refunded.toStringAsFixed(2)}", Colors.red),
      ],
    );
  }

  Widget _buildAmountPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileUserInfo(dynamic p) {
    return Column(
      children: [
        _buildUserInfoTile(
            "Customer", p['customer']?['email'] ?? "-", Icons.person_outline),
        const SizedBox(height: 8),
        _buildUserInfoTile(
            "Expert", p['expert']?['email'] ?? "-", Icons.engineering),
      ],
    );
  }

  Widget _buildWebUserInfo(dynamic p) {
    return Row(
      children: [
        Expanded(
          child: _buildUserInfoTile(
              "Customer", p['customer']?['email'] ?? "-", Icons.person_outline),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildUserInfoTile(
              "Expert", p['expert']?['email'] ?? "-", Icons.engineering),
        ),
      ],
    );
  }

  Widget _buildUserInfoTile(String title, String email, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF62C6D9).withOpacity(0.1),
            child: Icon(icon, size: 18, color: const Color(0xFF244C63)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, {required bool isLast}) {
    final action = (item['action'] ?? "").toString();
    final by = (item['by'] ?? "").toString();
    final at = _parseDate(item['at']);
    final meta = item['meta'];

    String dtText = "";
    if (at != null) {
      dtText =
          "${at.year.toString().padLeft(4, '0')}-${at.month.toString().padLeft(2, '0')}-${at.day.toString().padLeft(2, '0')} "
          "${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}";
    }

    IconData icon = Icons.circle;
    Color color = Colors.grey;

    switch (action) {
      case "AUTHORIZED":
        icon = Icons.lock_open;
        color = Colors.orange;
        break;
      case "CONFIRMED":
        icon = Icons.verified;
        color = Colors.blueAccent;
        break;
      case "CAPTURED":
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case "REFUND_REQUESTED":
        icon = Icons.reply;
        color = Colors.redAccent;
        break;
      case "REFUNDED":
        icon = Icons.check_circle_outline;
        color = Colors.redAccent;
        break;
      case "CANCELED":
        icon = Icons.cancel;
        color = Colors.grey;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: Icon(icon, size: 18, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: Colors.grey.withOpacity(0.3),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "By: $by",
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                if (dtText.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dtText,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
                if (meta != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Meta: ${meta.toString()}",
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}