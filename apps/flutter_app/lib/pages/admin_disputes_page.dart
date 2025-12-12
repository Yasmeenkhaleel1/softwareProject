// lib/admin_disputes_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ALL, OPEN, UNDER_REVIEW, RESOLVED_CUSTOMER, RESOLVED_EXPERT
  String _statusFilter = 'OPEN';

  // ✅ دالة للحصول على التوكن
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  Future<void> _fetchDisputes() async {
    if (!mounted) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }
      
      // استخدام ApiService.baseUrl
      final uri = Uri.parse('${ApiService.baseUrl}/admin/disputes');
      print('Fetching disputes from: $uri'); // ✅ للتصحيح

      final res = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      print('Response status: ${res.statusCode}'); // ✅ للتصحيح

      if (res.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else if (res.statusCode >= 400) {
        throw Exception('Failed to load disputes: ${res.statusCode}');
      }

      final body = jsonDecode(res.body);
      
      if (!mounted) return;
      
      // ✅ التحقق من بنية الرد بشكل آمن
      if (body is Map<String, dynamic>) {
        if (body.containsKey('success') && body['success'] == false) {
          throw Exception(body['message'] ?? 'Failed to load disputes');
        }
        
        final disputes = body['disputes'];
        if (disputes is List) {
          setState(() {
            _disputes = disputes;
          });
        } else {
          setState(() {
            _disputes = [];
          });
        }
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('Error fetching disputes: $e'); // ✅ للتصحيح
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<dynamic> get _visibleDisputes {
    if (_statusFilter == 'ALL') return _disputes;
    return _disputes
        .where((d) {
          final status = _getStringValue(d, 'status');
          return status.toUpperCase() == _statusFilter;
        })
        .toList();
  }

  int _countStatus(String status) {
    if (status == 'ALL') return _disputes.length;
    return _disputes
        .where((d) {
          final s = _getStringValue(d, 'status');
          return s.toUpperCase() == status;
        })
        .length;
  }

  // ✅ دالة مساعدة للحصول على القيم بشكل آمن
  String _getStringValue(dynamic data, String key) {
    if (data is Map) {
      final value = data[key];
      if (value is String) return value;
      if (value != null) return value.toString();
    }
    return '';
  }

  // ✅ دالة مساعدة للحصول على خريطة بشكل آمن
  Map<String, dynamic> _getMapValue(dynamic data, String key) {
    if (data is Map) {
      final value = data[key];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        // تحويل Map<dynamic, dynamic> إلى Map<String, dynamic>
        return Map<String, dynamic>.from(value);
      }
    }
    return {};
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'OPEN':
        return const Color(0xFFEB5757); // أحمر ناعم
      case 'UNDER_REVIEW':
        return const Color(0xFFF2C94C); // أصفر
      case 'RESOLVED_CUSTOMER':
        return const Color(0xFF27AE60); // أخضر
      case 'RESOLVED_EXPERT':
        return const Color(0xFF2D9CDB); // أزرق
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toUpperCase()) {
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
      builder: (_) => _DisputeDecisionDialog(
        dispute: dispute,
        onUpdate: _fetchDisputes,
      ),
    );

    if (updated == true) {
      await _fetchDisputes();
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF285E6E);

    // 🔹 محتوى الصفحة بدون Scaffold
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
                // ✅ العنوان + زر التحديث
                Row(
                  children: [
                    const Icon(Icons.gavel_outlined,
                        color: primary, size: 22),
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

                // عنوان وتعريف بسيط
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
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _error!,
                                        style: const TextStyle(color: Colors.red),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _fetchDisputes,
                                        child: const Text('Retry'),
                                      ),
                                    ],
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
                                        // عنوان الجدول
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
                                                    .map(
                                                      (d) =>
                                                          _buildDataRow(d),
                                                    )
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

  DataRow _buildDataRow(dynamic disputeData) {
    // ✅ استخدام الدوال المساعدة للحصول على البيانات بشكل آمن
    final booking = _getMapValue(disputeData, 'booking');
    final customer = _getMapValue(disputeData, 'customer');
    final expert = _getMapValue(disputeData, 'expert');
    final payment = _getMapValue(disputeData, 'payment');

    final createdAtStr = _getStringValue(disputeData, 'createdAt');
    String createdShort = '';
    if (createdAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAtStr);
        createdShort =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        createdShort = createdAtStr.length > 10 
            ? createdAtStr.substring(0, 10) 
            : createdAtStr;
      }
    }

    final amount = payment['amount'] ?? 0;
    final currency = payment['currency'] ?? 'USD';
    final type = _getStringValue(disputeData, 'type');
    final status = _getStringValue(disputeData, 'status');

    return DataRow(
      cells: [
        DataCell(Text(createdShort)),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_getStringValue(booking, 'code'),
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                _getStringValue(booking, 'status'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_getStringValue(customer, 'name')),
              const SizedBox(height: 2),
              Text(
                _getStringValue(customer, 'email'),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_getStringValue(expert, 'name')),
              const SizedBox(height: 2),
              Text(
                _getStringValue(expert, 'email'),
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
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
            onPressed: () {
              if (disputeData is Map<String, dynamic>) {
                _openDisputeDetails(disputeData);
              } else if (disputeData is Map) {
                // تحويل Map<dynamic, dynamic> إلى Map<String, dynamic>
                final converted = Map<String, dynamic>.from(disputeData);
                _openDisputeDetails(converted);
              }
            },
            child: const Text('View / Decide'),
          ),
        ),
      ],
    );
  }
}

/*───────────────────────────────
   كارت إحصائي صغير أعلى الصفحة
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
────────────────────────────────*/
class _DisputeDecisionDialog extends StatefulWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback? onUpdate;

  const _DisputeDecisionDialog({required this.dispute, this.onUpdate});

  @override
  State<_DisputeDecisionDialog> createState() =>
      _DisputeDecisionDialogState();
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
    
    // ✅ الحصول على القيمة بشكل آمن
    final resolution = dispute['resolution'];
    _resolution = (resolution is String) ? resolution : 'NONE';
    if (_resolution == 'NONE') _resolution = 'NO_REFUND';

    final refundAmount = dispute['refundAmount'] ?? 0;
    _refundController = TextEditingController(
      text: refundAmount.toString() == '0' ? '' : refundAmount.toString(),
    );

    final adminNotes = dispute['adminNotes'];
    _notesController = TextEditingController(
      text: adminNotes is String ? adminNotes : '',
    );
  }

  @override
  void dispose() {
    _refundController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openAttachment(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open attachment: $e')),
        );
      }
    }
  }

  // ✅ دالة للحصول على التوكن
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _saveDecision() async {
    final dispute = widget.dispute;
    
    // ✅ الحصول على payment بشكل آمن
    final payment = dispute['payment'] is Map<String, dynamic> 
        ? dispute['payment'] as Map<String, dynamic>
        : (dispute['payment'] is Map 
            ? Map<String, dynamic>.from(dispute['payment'] as Map) 
            : <String, dynamic>{});
    
    double? refundAmount;

    if (_resolution == 'REFUND_PARTIAL') {
      final text = _refundController.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a refund amount'),
          ),
        );
        return;
      }
      
      refundAmount = double.tryParse(text);
      if (refundAmount == null || refundAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid refund amount'),
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
      final token = await _getToken();
      if (token == null) {
        throw Exception('No authentication token');
      }
      
      final url = '${ApiService.baseUrl}/admin/disputes/${dispute['_id']}/decision';
      print('Saving decision to: $url'); // ✅ للتصحيح

      final body = <String, dynamic>{
        'resolution': _resolution,
        'refundAmount': refundAmount,
        'adminNotes': _notesController.text.trim(),
      };

      final res = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      print('Save response: ${res.statusCode}'); // ✅ للتصحيح

      if (res.statusCode == 401) {
        throw Exception('Unauthorized - Please login again');
      } else if (res.statusCode >= 400) {
        throw Exception('Failed to save: ${res.body}');
      }

      final result = jsonDecode(res.body);
      if (result is Map && result.containsKey('success') && result['success'] == false) {
        throw Exception(result['message'] ?? 'Failed to save decision');
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      
      // ✅ استدعاء callback لتحديث البيانات
      widget.onUpdate?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dispute decision saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving decision: $e'); // ✅ للتصحيح
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
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
    
    // ✅ الحصول على البيانات بشكل آمن
    final booking = dispute['booking'] is Map<String, dynamic> 
        ? dispute['booking'] as Map<String, dynamic>
        : (dispute['booking'] is Map 
            ? Map<String, dynamic>.from(dispute['booking'] as Map) 
            : <String, dynamic>{});
            
    final customer = dispute['customer'] is Map<String, dynamic> 
        ? dispute['customer'] as Map<String, dynamic>
        : (dispute['customer'] is Map 
            ? Map<String, dynamic>.from(dispute['customer'] as Map) 
            : <String, dynamic>{});
            
    final expert = dispute['expert'] is Map<String, dynamic> 
        ? dispute['expert'] as Map<String, dynamic>
        : (dispute['expert'] is Map 
            ? Map<String, dynamic>.from(dispute['expert'] as Map) 
            : <String, dynamic>{});
            
    final payment = dispute['payment'] is Map<String, dynamic> 
        ? dispute['payment'] as Map<String, dynamic>
        : (dispute['payment'] is Map 
            ? Map<String, dynamic>.from(dispute['payment'] as Map) 
            : <String, dynamic>{});
    
    final attachments = dispute['attachments'] is List
        ? (dispute['attachments'] as List).whereType<String>().toList()
        : <String>[];

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                              customer['name']?.toString() ?? '-',
                              customer['email']?.toString() ?? '',
                            ],
                          ),
                          _infoBox(
                            title: 'Expert',
                            lines: [
                              expert['name']?.toString() ?? '-',
                              expert['email']?.toString() ?? '',
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
                          dispute['customerMessage']?.toString() ?? '',
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
                              style:
                                  TextStyle(fontSize: 13, color: Colors.grey),
                            )
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: attachments.map((url) {
                                final fileName =
                                    Uri.parse(url).pathSegments.last;
                                return ActionChip(
                                  onPressed: () => _openAttachment(url),
                                  avatar: const Icon(Icons.attach_file,
                                      size: 18),
                                  label: Text(
                                    fileName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
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