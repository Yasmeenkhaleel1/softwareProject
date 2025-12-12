// lib/admin_disputes_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';

class AdminDisputesPage extends StatefulWidget {
  const AdminDisputesPage({super.key});

  @override
  State<AdminDisputesPage> createState() => _AdminDisputesPageState();
}

class _AdminDisputesPageState extends State<AdminDisputesPage> {
  bool _loading = true;
  String? _error;
  List<dynamic> _disputes = [];
  String _statusFilter = 'OPEN';

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  Future<void> _fetchDisputes() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await ApiService.getToken();
      final uri = Uri.parse('${ApiService.baseUrl}/admin/disputes');

      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode >= 400) {
        throw Exception('Failed to load disputes: ${res.body}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      setState(() {
        _disputes = (body['disputes'] as List?) ?? [];
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  List<dynamic> get _visibleDisputes {
    if (_statusFilter == 'ALL') return _disputes;
    return _disputes
        .where((d) => (d['status'] ?? '') == _statusFilter)
        .toList();
  }

  int _countStatus(String status) {
    if (status == 'ALL') return _disputes.length;
    return _disputes.where((d) => d['status'] == status).length;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFFEB5757);
      case 'UNDER_REVIEW':
        return const Color(0xFFF2C94C);
      case 'RESOLVED_CUSTOMER':
        return const Color(0xFF27AE60);
      case 'RESOLVED_EXPERT':
        return const Color(0xFF2D9CDB);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'UNDER_REVIEW':
        return 'Under review';
      case 'RESOLVED_CUSTOMER':
        return 'Resolved (customer)';
      case 'RESOLVED_EXPERT':
        return 'Resolved (expert)';
      case 'ALL':
        return 'All disputes';
      default:
        return status;
    }
  }

  Future<void> _openDisputeDetails(Map<String, dynamic> dispute) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DisputeDecisionDialog(dispute: dispute),
    );

    if (updated == true) {
      _fetchDisputes();
    }
  }

  // ======================
  // BUILD (RESPONSIVE)
  // ======================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    return isMobile ? _buildMobileView() : _buildWebView();
  }

  // ======================================================
  // 🔒 WEB VIEW — كودك الأصلي بدون أي تغيير
  // ======================================================
  Widget _buildWebView() {
    const primary = Color(0xFF285E6E);

    return Container(
      color: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel_outlined, color: primary, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'Disputes & Refunds',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _fetchDisputes,
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customer disputes & refund requests',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Review disputes, check customer messages and attachments, '
                  'and decide whether a refund should be issued.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // الكروت الإحصائية
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatCard(
                        label: 'All disputes',
                        value: _countStatus('ALL').toString(),
                        color: const Color(0xFF4C6FFF),
                        icon: Icons.all_inbox_outlined,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Open',
                        value: _countStatus('OPEN').toString(),
                        color: const Color(0xFFEB5757),
                        icon: Icons.markunread_mailbox_outlined,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Under review',
                        value: _countStatus('UNDER_REVIEW').toString(),
                        color: const Color(0xFFF2C94C),
                        icon: Icons.manage_search_outlined,
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: 'Resolved',
                        value: (_countStatus('RESOLVED_CUSTOMER') +
                                _countStatus('RESOLVED_EXPERT'))
                            .toString(),
                        color: const Color(0xFF27AE60),
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // الفلاتر
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('ALL'),
                    _buildFilterChip('OPEN'),
                    _buildFilterChip('UNDER_REVIEW'),
                    _buildFilterChip('RESOLVED_CUSTOMER'),
                    _buildFilterChip('RESOLVED_EXPERT'),
                  ],
                ),

                const SizedBox(height: 16),

                // الجدول الرئيسي
                Expanded(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                )
                              : _visibleDisputes.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No disputes found for this filter.',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  : Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${_visibleDisputes.length} dispute(s) found',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: SingleChildScrollView(
                                              child: DataTable(
                                                columnSpacing: 30,
                                                headingRowHeight: 30,
                                                dataRowMinHeight: 70,
                                                dataRowMaxHeight: 90,
                                                columns: const [
                                                  DataColumn(
                                                    label: Text(
                                                      'Created',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Booking',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Customer',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Expert',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Amount',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Type',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Status',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                    label: Text(
                                                      'Action',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                                rows: _visibleDisputes
                                                    .map((d) => _buildDataRow(d))
                                                    .toList(),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ======================================================
  // 📱 MOBILE VIEW — تصميم محترف مع الاحتفاظ بكل الميزات
  // ======================================================
  Widget _buildMobileView() {
    return Container(
      color: const Color(0xFFF4F7FB),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header للموبايل
          Row(
            children: [
              const Icon(Icons.gavel_outlined, color: Color(0xFF285E6E), size: 22),
              const SizedBox(width: 8),
              const Text(
                'Disputes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF285E6E),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _fetchDisputes,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Customer disputes & refund requests',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Stats Cards للموبايل (2 في الصف)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _MobileStatCard(
                label: 'All',
                value: _countStatus('ALL').toString(),
                color: const Color(0xFF4C6FFF),
              ),
              _MobileStatCard(
                label: 'Open',
                value: _countStatus('OPEN').toString(),
                color: const Color(0xFFEB5757),
              ),
              _MobileStatCard(
                label: 'Review',
                value: _countStatus('UNDER_REVIEW').toString(),
                color: const Color(0xFFF2C94C),
              ),
              _MobileStatCard(
                label: 'Resolved',
                value: (_countStatus('RESOLVED_CUSTOMER') +
                        _countStatus('RESOLVED_EXPERT'))
                    .toString(),
                color: const Color(0xFF27AE60),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // الفلاتر للموبايل (Scrollable)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const SizedBox(width: 4),
                _buildMobileFilterChip('ALL'),
                const SizedBox(width: 8),
                _buildMobileFilterChip('OPEN'),
                const SizedBox(width: 8),
                _buildMobileFilterChip('UNDER_REVIEW'),
                const SizedBox(width: 8),
                _buildMobileFilterChip('RESOLVED_CUSTOMER'),
                const SizedBox(width: 8),
                _buildMobileFilterChip('RESOLVED_EXPERT'),
                const SizedBox(width: 4),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // قائمة النزاعات للموبايل
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _visibleDisputes.isEmpty
                        ? const Center(
                            child: Text(
                              'No disputes found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _visibleDisputes.length,
                            separatorBuilder: (_, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final d = _visibleDisputes[index];
                              final booking = (d['booking'] ?? {}) as Map<String, dynamic>;
                              final customer = (d['customer'] ?? {}) as Map<String, dynamic>;
                              final expert = (d['expert'] ?? {}) as Map<String, dynamic>;
                              final payment = (d['payment'] ?? {}) as Map<String, dynamic>;
                              
                              return _buildMobileDisputeCard(
                                d,
                                booking,
                                customer,
                                expert,
                                payment,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDisputeCard(
    Map<String, dynamic> d,
    Map<String, dynamic> booking,
    Map<String, dynamic> customer,
    Map<String, dynamic> expert,
    Map<String, dynamic> payment,
  ) {
    final createdAtStr = d['createdAt']?.toString();
    String createdShort = '';
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr);
        createdShort = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {
        createdShort = createdAtStr;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () => _openDisputeDetails(d),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: Customer و Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      customer['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    createdShort,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Booking Code و Expert
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      booking['code'] ?? 'N/A',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      expert['name'] ?? 'Unknown expert',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // الصف الثالث: Amount و Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${payment['amount'] ?? 0} ${payment['currency'] ?? 'USD'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Color(0xFF285E6E),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(d['status'] ?? '').withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(d['status'] ?? ''),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(d['status'] ?? ''),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // نوع النزاع
              if ((d['type'] ?? '').isNotEmpty)
                Text(
                  'Type: ${d['type']}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFilterChip(String status) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text(
        _statusLabel(status),
        style: TextStyle(
          fontSize: 13,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Colors.white : Colors.black87,
        ),
      ),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = status;
        });
      },
      selectedColor: const Color(0xFF285E6E),
      backgroundColor: const Color(0xFFE8EDF5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text(_statusLabel(status)),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = status;
        });
      },
      selectedColor: const Color(0xFF285E6E),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: const Color(0xFFE8EDF5),
    );
  }

  DataRow _buildDataRow(Map<String, dynamic> d) {
    final booking = (d['booking'] ?? {}) as Map<String, dynamic>;
    final customer = (d['customer'] ?? {}) as Map<String, dynamic>;
    final expert = (d['expert'] ?? {}) as Map<String, dynamic>;
    final payment = (d['payment'] ?? {}) as Map<String, dynamic>;

    final createdAtStr = d['createdAt']?.toString();
    String createdShort = '';
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr);
        createdShort = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        createdShort = createdAtStr;
      }
    }

    final amount = payment['amount'] ?? 0;
    final currency = payment['currency'] ?? 'USD';
    final type = d['type'] ?? '';
    final status = d['status'] ?? '';

    return DataRow(
      cells: [
        DataCell(Text(createdShort)),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(booking['code'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                booking['status'] ?? '',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(customer['name'] ?? '-'),
              const SizedBox(height: 2),
              Text(customer['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(expert['name'] ?? '-'),
              const SizedBox(height: 2),
              Text(expert['email'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        DataCell(Text('$amount $currency')),
        DataCell(Text(type)),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusColor(status),
              ),
            ),
          ),
        ),
        DataCell(
          TextButton(
            onPressed: () => _openDisputeDetails(d),
            child: const Text('View / Decide'),
          ),
        ),
      ],
    );
  }
}

/*───────────────────────────────
   كارت إحصائي للموبايل
────────────────────────────────*/
class _MobileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MobileStatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
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
}

/*───────────────────────────────
   كارت إحصائي للويب (نفس الكود الأصلي)
────────────────────────────────*/
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 12,
            offset: Offset(0, 4),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*───────────────────────────────
  Dialog لعرض تفاصيل النزاع + اتخاذ القرار
  (نفس كودك الأصلي بدون أي تعديل)
────────────────────────────────*/
class _DisputeDecisionDialog extends StatefulWidget {
  final Map<String, dynamic> dispute;

  const _DisputeDecisionDialog({required this.dispute});

  @override
  State<_DisputeDecisionDialog> createState() => _DisputeDecisionDialogState();
}

class _DisputeDecisionDialogState extends State<_DisputeDecisionDialog> {
  late String _resolution; // NONE / REFUND_FULL / REFUND_PARTIAL / NO_REFUND
  late TextEditingController _refundController;
  late TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final dispute = widget.dispute;
    _resolution = (dispute['resolution'] ?? 'NONE') as String;
    if (_resolution == 'NONE') _resolution = 'NO_REFUND';

    final refundAmount = (dispute['refundAmount'] ?? 0).toString();
    _refundController = TextEditingController(
      text: refundAmount == '0' ? '' : refundAmount,
    );

    _notesController =
        TextEditingController(text: dispute['adminNotes']?.toString() ?? '');
  }

  @override
  void dispose() {
    _refundController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _saveDecision() async {
    final dispute = widget.dispute;
    final payment = (dispute['payment'] ?? {}) as Map<String, dynamic>;
    double? refundAmount;

    if (_resolution == 'REFUND_PARTIAL') {
      refundAmount = double.tryParse(_refundController.text.trim());
      if (refundAmount == null || refundAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid partial refund amount'),
          ),
        );
        return;
      }
    } else if (_resolution == 'REFUND_FULL') {
      final total = (payment['amount'] ?? 0).toDouble();
      refundAmount = total;
    } else {
      refundAmount = 0;
    }

    setState(() {
      _saving = true;
    });

    try {
      final token = await ApiService.getToken();
      final url = '${ApiService.baseUrl}/admin/disputes/${dispute['_id']}/decision';

      final body = <String, dynamic>{
        'resolution': _resolution,
        'refundAmount': refundAmount,
        'adminNotes': _notesController.text.trim(),
      };

      final res = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode >= 400) {
        throw Exception('Failed to save: ${res.body}');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute decision saved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispute = widget.dispute;
    final booking = (dispute['booking'] ?? {}) as Map<String, dynamic>;
    final customer = (dispute['customer'] ?? {}) as Map<String, dynamic>;
    final expert = (dispute['expert'] ?? {}) as Map<String, dynamic>;
    final payment = (dispute['payment'] ?? {}) as Map<String, dynamic>;
    final attachments = (dispute['attachments'] as List?)?.cast<String>() ?? [];

    const accent = Color(0xFF285E6E);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, minHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                color: Color(0xFFF4F7FB),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gavel_outlined, color: accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Dispute details & decision',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking + payment summary
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        children: [
                          _infoBox(
                            title: 'Booking',
                            lines: [
                              'Code: ${booking['code'] ?? '-'}',
                              'Status: ${booking['status'] ?? '-'}',
                            ],
                          ),
                          _infoBox(
                            title: 'Customer',
                            lines: [
                              customer['name'] ?? '-',
                              customer['email'] ?? '',
                            ],
                          ),
                          _infoBox(
                            title: 'Expert',
                            lines: [
                              expert['name'] ?? '-',
                              expert['email'] ?? '',
                            ],
                          ),
                          _infoBox(
                            title: 'Payment',
                            lines: [
                              'Amount: ${payment['amount'] ?? 0} ${payment['currency'] ?? 'USD'}',
                              'Status: ${payment['status'] ?? '-'}',
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Customer message
                      const Text(
                        'Customer message',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0xFFF8FAFC),
                          border: Border.all(color: const Color(0xFFE0E6F0)),
                        ),
                        child: Text(
                          dispute['customerMessage'] ?? '',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Attachments
                      const Text(
                        'Attachments',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      attachments.isEmpty
                          ? const Text(
                              'No attachments provided.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: attachments.map((url) {
                                final fileName = Uri.parse(url).pathSegments.last;
                                return ActionChip(
                                  onPressed: () => _openAttachment(url),
                                  avatar: const Icon(Icons.attach_file, size: 18),
                                  label: Text(
                                    fileName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                            ),

                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Decision section
                      const Text(
                        'Admin decision',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _resolution,
                              decoration: const InputDecoration(
                                labelText: 'Resolution',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'NO_REFUND',
                                  child: Text('No refund'),
                                ),
                                DropdownMenuItem(
                                  value: 'REFUND_FULL',
                                  child: Text('Full refund'),
                                ),
                                DropdownMenuItem(
                                  value: 'REFUND_PARTIAL',
                                  child: Text('Partial refund'),
                                ),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (v) {
                                      if (v != null) {
                                        setState(() {
                                          _resolution = v;
                                        });
                                      }
                                    },
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (_resolution == 'REFUND_PARTIAL')
                            Expanded(
                              child: TextFormField(
                                controller: _refundController,
                                decoration: const InputDecoration(
                                  labelText: 'Partial amount',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                enabled: !_saving,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Admin notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_saving,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _saveDecision,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save decision'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox({required String title, required List<String> lines}) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E6F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          ...lines.map(
            (l) => Text(
              l,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}