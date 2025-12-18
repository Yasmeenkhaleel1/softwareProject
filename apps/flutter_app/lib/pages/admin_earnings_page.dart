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
  // Use real computer IP
  String getBaseUrl() {
    // Check for web platform
    if (kIsWeb) {
      return "http://localhost:5000"; // For web browser
    }
    
    // For mobile/desktop
    if (Platform.isAndroid) {
      return "http://10.0.2.2:5000"; // Android emulator
    } else if (Platform.isIOS) {
      return "http://localhost:5000"; // iOS simulator
    } else {
      return "http://localhost:5000"; // Desktop/Web
    }
  }
  
  final Color brand = const Color(0xFF62C6D9);
  final Color darkBlue = const Color(0xFF244C63);
  final Color lightBlue = const Color(0xFF62C6D9);
  final Color mediumBlue = const Color(0xFF347C8B);

  bool _loading = false;
  String? _error;
  bool _demoMode = false; // Changed to false by default

  // Data
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

  // Filters
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
      print('Loading from: $baseUrl'); // Debug log
      
      // Try to load real data first
      final token = await _getToken();
      
      if (token == null || token.isEmpty) {
        throw Exception("Please login first");
      }
      
      // Try to get summary
      final summaryResponse = await http.get(
        Uri.parse("$baseUrl/api/admin/earnings/summary"),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      
      print('Summary status: ${summaryResponse.statusCode}'); // Debug
      
      if (summaryResponse.statusCode == 200) {
        final data = jsonDecode(summaryResponse.body);
        print('Summary data: $data'); // Debug
        
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
        
        // Now load payments
        await _loadPayments(token);
        
      } else {
        throw Exception("Server error: ${summaryResponse.statusCode}");
      }
      
    } catch (e) {
      print('Error loading data: $e'); // Debug
      
      // If connection fails, use demo data
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
      
      print('Payments status: ${paymentsResponse.statusCode}'); // Debug
      
      if (paymentsResponse.statusCode == 200) {
        final data = jsonDecode(paymentsResponse.body);
        print('Payments data received, items: ${data['items']?.length ?? 0}'); // Debug
        
        if (data['items'] != null && data['items'] is List) {
          final items = List<Map<String, dynamic>>.from(data['items'] as List);
          
          if (!mounted) return;
          
          setState(() {
            payments = items;
            filteredPayments = List.from(payments);
            paymentsCount = payments.length; // Update count
          });
          
          print('Loaded ${payments.length} payments'); // Debug
        } else {
          print('No items in response or wrong format'); // Debug
          throw Exception('Invalid payments data format');
        }
      } else {
        throw Exception("Payments error: ${paymentsResponse.statusCode}");
      }
    } catch (e) {
      print('Error loading payments: $e'); // Debug
      // Load demo payments if real ones fail
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
    // Demo summary data
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
    // Generate fake data
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
        'customer': {
          'name': customerNames[index % customerNames.length],
          'email': 'customer${index + 1}@example.com'
        },
        'expert': {
          'name': expertNames[index % expertNames.length],
          'email': 'expert${index + 1}@example.com'
        },
        'service': {'title': services[index % services.length]},
        'booking': {'code': 'BOOK-${2000 + index}'},
        'createdAt': DateTime.now().subtract(Duration(days: index, hours: index * 2)).toIso8601String(),
      };
    });
    
    setState(() {
      payments = demoPayments;
      filteredPayments = List.from(demoPayments);
      _applyFilters(); // Apply initial filter
    });
  }

  void _applyFilters() {
    if (statusFilter == "ALL") {
      filteredPayments = List.from(payments);
    } else {
      filteredPayments = payments
          .where((p) => p['status'] == statusFilter)
          .toList();
    }
    if (mounted) setState(() {});
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "CAPTURED":
        return Colors.green;
      case "AUTHORIZED":
        return Colors.orange;
      case "REFUND_PENDING":
        return Colors.deepOrange;
      case "REFUNDED":
        return Colors.redAccent;
      case "FAILED":
        return Colors.grey;
      default:
        return Colors.blueGrey;
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

  Widget _buildErrorView() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(
                _error ?? "An error occurred",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.red),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text("Try Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: brand,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: brand),
            const SizedBox(height: 20),
            const Text(
              "Loading data...",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoadingView();
    if (_error != null && !_demoMode) return _buildErrorView();
    
    final isMobile = MediaQuery.of(context).size.width < 900;
    return isMobile ? _buildMobileView() : _buildWebView();
  }

  // ======================
  // 📱 MOBILE VIEW
  // ======================
  Widget _buildMobileView() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            backgroundColor: darkBlue,
            expandedHeight: 160,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF62C6D9), Color(0xFF347C8B), Color(0xFF244C63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 100, left: 20, right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Revenue & Earnings",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _demoMode ? "Demo Mode - Sample Data" : "Live Data",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Filters",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF244C63),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: statusFilter,
                        decoration: InputDecoration(
                          labelText: "Payment Status",
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
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _loadData,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text("Refresh"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: brand,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: () {
                              _showConnectionInfo();
                            },
                            icon: const Icon(Icons.info_outline),
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Stats Summary
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Main Stats Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF62C6D9), Color(0xFF347C8B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.attach_money, color: Colors.white),
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
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    "\$${totalProcessed.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildMiniStat("Payments", "$paymentsCount", Icons.payments),
                            _buildMiniStat("Experts", "\$${totalNetToExperts.toStringAsFixed(0)}", Icons.people),
                            _buildMiniStat("Profit", "\$${totalPlatformFees.toStringAsFixed(0)}", Icons.trending_up),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      _buildStatCard(
                        "Net to Experts",
                        "\$${totalNetToExperts.toStringAsFixed(2)}",
                        Colors.green,
                        Icons.person_outline,
                      ),
                      _buildStatCard(
                        "Platform Fees",
                        "\$${totalPlatformFees.toStringAsFixed(2)}",
                        Colors.orange,
                        Icons.account_balance,
                      ),
                      _buildStatCard(
                        "Refunded",
                        "\$${totalRefunds.toStringAsFixed(2)}",
                        Colors.red,
                        Icons.reply,
                      ),
                      _buildStatCard(
                        "Captured",
                        "${statusCounts['CAPTURED'] ?? 0}",
                        Colors.blue,
                        Icons.check_circle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Payments List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  const Text(
                    "Payments History",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF244C63),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${filteredPayments.length} payments",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Payments List - FIXED: Now properly displays payments
          if (filteredPayments.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(32),
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
                    Icon(Icons.payments_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text(
                      "No payments found",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Try changing filters",
                      style: TextStyle(
                        fontSize: 14,
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
                  final payment = filteredPayments[index];
                  return _buildPaymentCard(payment);
                },
                childCount: filteredPayments.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF244C63),
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

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final status = payment['status'] as String;
    final amount = (payment['amount'] ?? 0).toDouble();
    final customer = payment['customer'] as Map<String, dynamic>;
    final expert = payment['expert'] as Map<String, dynamic>;
    final service = payment['service'] as Map<String, dynamic>;
    final createdAt = payment['createdAt'] as String;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
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
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payment,
                      color: _getStatusColor(status),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['title'] ?? 'Service',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF244C63),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          customer['name'] ?? 'Customer',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
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
                      const Text(
                        "Amount",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "\$${amount.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF244C63),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Expert",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 120,
                        child: Text(
                          expert['name'] ?? 'Expert',
                          style: const TextStyle(
                            fontSize: 14,
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

              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Date: ${createdAt.substring(0, 10)}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (status == "CAPTURED")
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        "Successful",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================
  // 🖥️ WEB VIEW
  // ======================
  Widget _buildWebView() {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF62C6D9), Color(0xFF347C8B), Color(0xFF244C63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Earnings Dashboard",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _demoMode 
                                ? "Demo Mode - Showing sample data for testing"
                                : "Monitor revenue and earnings in real-time",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text("Refresh Data"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: darkBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton.icon(
                                onPressed: () => _showConnectionInfo(),
                                icon: const Icon(Icons.info_outline),
                                label: Text(_demoMode ? "Demo Mode" : "Connected"),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Total Processed",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "\$${totalProcessed.toStringAsFixed(2)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$paymentsCount payments",
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Filters
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Filters & Search",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF244C63),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          SizedBox(
                            width: 300,
                            child: DropdownButtonFormField<String>(
                              value: statusFilter,
                              decoration: InputDecoration(
                                labelText: "Filter by Status",
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
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: "Search by customer, expert, or service...",
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                              ),
                              onChanged: (value) {
                                // Search functionality can be added here
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Stats Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.5,
                children: [
                  _buildWebStatCard(
                    "Net to Experts",
                    "\$${totalNetToExperts.toStringAsFixed(2)}",
                    Colors.green,
                    Icons.person_outline,
                    "Amount transferred to experts",
                  ),
                  _buildWebStatCard(
                    "Platform Fees",
                    "\$${totalPlatformFees.toStringAsFixed(2)}",
                    Colors.orange,
                    Icons.account_balance,
                    "Platform commission",
                  ),
                  _buildWebStatCard(
                    "Refunded Amount",
                    "\$${totalRefunds.toStringAsFixed(2)}",
                    Colors.red,
                    Icons.reply,
                    "Total refunded amount",
                  ),
                  _buildWebStatCard(
                    "Successful Payments",
                    "${statusCounts['CAPTURED'] ?? 0}",
                    Colors.blue,
                    Icons.check_circle,
                    "Successfully captured payments",
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Payments Table - FIXED: Now properly displays payments
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Payments History",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF244C63),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${filteredPayments.length} payments",
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (filteredPayments.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.payments_outlined, size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                "No payments match the selected filters",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 50,
                            dataRowHeight: 60,
                            columnSpacing: 24,
                            horizontalMargin: 16,
                            columns: const [
                              DataColumn(label: Text("Service")),
                              DataColumn(label: Text("Customer")),
                              DataColumn(label: Text("Expert")),
                              DataColumn(label: Text("Amount")),
                              DataColumn(label: Text("Status")),
                              DataColumn(label: Text("Date")),
                            ],
                            rows: filteredPayments.take(10).map((payment) {
                              final status = payment['status'] as String;
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 200,
                                      child: Text(
                                        payment['service']['title'] ?? 'Service',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(payment['customer']['name'] ?? 'Customer'),
                                  ),
                                  DataCell(
                                    Text(payment['expert']['name'] ?? 'Expert'),
                                  ),
                                  DataCell(
                                    Text(
                                      "\$${(payment['amount'] ?? 0).toStringAsFixed(2)}",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getStatusText(status),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text((payment['createdAt'] as String).substring(0, 10)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebStatCard(String title, String value, Color color, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF244C63),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                _loadData(); // Try to reload real data
              },
              child: const Text("Try Connect"),
            ),
        ],
      ),
    );
  }
}

