// lib/admin_disputes_page.dart
import 'dart:convert';
import 'dart:math' as math;

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

  // ✅ نخليها Map<String,dynamic>
  List<Map<String, dynamic>> _disputes = [];

  // ALL, OPEN, UNDER_REVIEW, RESOLVED_CUSTOMER
  String _statusFilter = 'OPEN';

  @override
  void initState() {
    super.initState();
    _fetchDisputes();
  }

  // =========================
  // ✅ LOGIC (NO CHANGES)
  // =========================
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
      final rawList = (body['disputes'] as List?) ?? [];

      setState(() {
        _disputes = rawList
            .whereType<Map>()
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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

  List<Map<String, dynamic>> get _visibleDisputes {
    if (_statusFilter == 'ALL') return _disputes;
    return _disputes.where((d) => (d['status'] ?? '') == _statusFilter).toList();
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
      
      case 'ALL':
        return 'All disputes';
      default:
        return status;
    }
  }

  Future<void> _openDisputeDetails(Map<String, dynamic> dispute) async {
    final safeDispute = Map<String, dynamic>.from(dispute);

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DisputeDecisionDialog(dispute: safeDispute),
    );

    if (updated == true) {
      _fetchDisputes();
    }
  }

  // =========================
  // ✅ UI THEME
  // =========================
  static const Color _primary = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isMobile = w < 760;
        final isWide = w >= 1100;

        return Container(
          color: _bg,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 14 : 24),
                // ✅ أهم تغيير: الصفحة كلها Slivers (Scrollable) لمنع overflow نهائيًا
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _HeaderBar(
                        title: 'Disputes & Refunds',
                        subtitle: 'Customer disputes & refund requests',
                        hint:
                            'Review disputes, check customer messages and attachments, and decide whether a refund should be issued.',
                        onRefresh: _fetchDisputes,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 14)),

                    // ===== Dashboard Row (Stats + Chart)
                    SliverToBoxAdapter(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _buildStatsPanel(isMobile: false)),
                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 420,
                                  child: _ChartCard(
                                    title: 'Disputes overview',
                                    subtitle: 'Distribution by status',
                                    child: _StatusDonut(
                                      open: _countStatus('OPEN'),
                                      review: _countStatus('UNDER_REVIEW'),
                                      resolvedCustomer: _countStatus('RESOLVED_CUSTOMER'),
                                      resolvedExpert: _countStatus('RESOLVED_EXPERT'),
                                      primary: _primary,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildStatsPanel(isMobile: isMobile),
                                const SizedBox(height: 12),
                                _ChartCard(
                                  title: 'Disputes overview',
                                  subtitle: 'Distribution by status',
                                  child: _StatusDonut(
                                    open: _countStatus('OPEN'),
                                    review: _countStatus('UNDER_REVIEW'),
                                    resolvedCustomer: _countStatus('RESOLVED_CUSTOMER'),
                                    resolvedExpert: _countStatus('RESOLVED_EXPERT'),
                                    primary: _primary,
                                  ),
                                ),
                              ],
                            ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    SliverToBoxAdapter(
                      child: _FiltersCard(
                        primary: _primary,
                        statusFilter: _statusFilter,
                        onSelect: (s) => setState(() => _statusFilter = s),
                        labelFor: _statusLabel,
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // ===== BODY (no overflow)
                    if (_loading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _SurfaceCard(
                          child: _EmptyState(
                            icon: Icons.error_outline,
                            title: 'Something went wrong',
                            subtitle: _error!,
                            tone: _EmptyTone.danger,
                          ),
                        ),
                      )
                    else if (_visibleDisputes.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _SurfaceCard(
                          child: _EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'No disputes found',
                            subtitle: 'No disputes match the selected filter.',
                            tone: _EmptyTone.neutral,
                          ),
                        ),
                      )
                    else if (isMobile)
                      SliverList.separated(
                        itemCount: _visibleDisputes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _DisputeMobileCard(
                          d: _visibleDisputes[i],
                          statusLabel: _statusLabel,
                          statusColor: _statusColor,
                          onOpen: _openDisputeDetails,
                        ),
                      )
                    else
                      SliverFillRemaining(
                        hasScrollBody: true,
                        child: _SurfaceCard(
                          child: _WebDisputesTable(
                            disputes: _visibleDisputes,
                            statusLabel: _statusLabel,
                            statusColor: _statusColor,
                            onOpen: _openDisputeDetails,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsPanel({required bool isMobile}) {
    final all = _countStatus('ALL');
    final open = _countStatus('OPEN');
    final review = _countStatus('UNDER_REVIEW');

    final resolved = _countStatus('RESOLVED_CUSTOMER');


    final cards = [
      _StatCard(
        label: 'All disputes',
        value: all.toString(),
        color: const Color(0xFF4C6FFF),
        icon: Icons.all_inbox_outlined,
      ),
      _StatCard(
        label: 'Open',
        value: open.toString(),
        color: const Color(0xFFEB5757),
        icon: Icons.markunread_mailbox_outlined,
      ),
      _StatCard(
        label: 'Under review',
        value: review.toString(),
        color: const Color(0xFFF2C94C),
        icon: Icons.manage_search_outlined,
      ),
      _StatCard(
        label: 'Resolved',
        value: resolved.toString(),
        color: const Color(0xFF27AE60),
        icon: Icons.check_circle_outline,
      ),
    ];

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(width: 10),
            ],
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: cards.map((c) => SizedBox(width: 260, child: c)).toList(),
    );
  }
}

/*────────────────────────  Header  ────────────────────────*/

class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final String hint;
  final VoidCallback onRefresh;

  const _HeaderBar({
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.onRefresh,
  });

  static const Color primary = Color(0xFF285E6E);

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.gavel_outlined, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Refresh',
            child: IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
    );
  }
}

/*────────────────────────  Filters  ────────────────────────*/

class _FiltersCard extends StatelessWidget {
  final Color primary;
  final String statusFilter;
  final ValueChanged<String> onSelect;
  final String Function(String) labelFor;

  const _FiltersCard({
    required this.primary,
    required this.statusFilter,
    required this.onSelect,
    required this.labelFor,
  });

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'ALL',
      'OPEN',
      'UNDER_REVIEW',
      'RESOLVED_CUSTOMER',
      'RESOLVED_EXPERT',

    ];

    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: statuses.map((s) {
          final selected = statusFilter == s;
          return ChoiceChip(
            label: Text(labelFor(s)),
            selected: selected,
            onSelected: (_) => onSelect(s),
            selectedColor: primary,
            backgroundColor: const Color(0xFFE8EDF5),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/*────────────────────────  Surface Card  ────────────────────────*/

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 4,
      shadowColor: const Color(0x14000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: padding, child: child),
    );
  }
}

/*────────────────────────  Empty States  ────────────────────────*/

enum _EmptyTone { neutral, danger }

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _EmptyTone tone;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        (tone == _EmptyTone.danger) ? const Color(0xFFEB5757) : const Color(0xFF6B7280);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

/*────────────────────────  Web Table  ────────────────────────*/

class _WebDisputesTable extends StatelessWidget {
  final List<Map<String, dynamic>> disputes;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final void Function(Map<String, dynamic>) onOpen;

  const _WebDisputesTable({
    required this.disputes,
    required this.statusLabel,
    required this.statusColor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              '${disputes.length} dispute(s) found',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),
        const Divider(height: 1),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 1100),
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 26,
                  headingRowHeight: 42,
                  dataRowMinHeight: 72,
                  dataRowMaxHeight: 92,
                  headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
                  columns: const [
                    DataColumn(label: Text('Created')),
                    DataColumn(label: Text('Booking')),
                    DataColumn(label: Text('Customer')),
                    DataColumn(label: Text('Expert')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Action')),
                  ],
                  rows: disputes.map((d) {
                    final booking = (d['booking'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
                    final customer = (d['customer'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
                    final expert = (d['expert'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
                    final payment = (d['payment'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

                    final createdAtStr = d['createdAt']?.toString();
                    String createdShort = '';
                    if (createdAtStr != null) {
                      try {
                        final dt = DateTime.parse(createdAtStr);
                        createdShort =
                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                      } catch (_) {
                        createdShort = createdAtStr;
                      }
                    }

                    final amount = payment['amount'] ?? 0;
                    final currency = payment['currency'] ?? 'USD';
                    final type = d['type'] ?? '';
                    final status = (d['status'] ?? '').toString();

                    return DataRow(
                      cells: [
                        DataCell(Text(createdShort)),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(booking['code'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(
                                booking['status'] ?? '',
                                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(customer['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(customer['email'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                            ],
                          ),
                        ),
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(expert['name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(expert['email'] ?? '', style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                            ],
                          ),
                        ),
                        DataCell(Text('$amount $currency', style: const TextStyle(fontWeight: FontWeight.w700))),
                        DataCell(Text(type.toString())),
                        DataCell(_StatusChip(label: statusLabel(status), color: statusColor(status))),
                        DataCell(
                          FilledButton.tonal(
                            onPressed: () => onOpen(d),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('View / Decide'),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/*────────────────────────  Mobile Card  ────────────────────────*/

class _DisputeMobileCard extends StatelessWidget {
  final Map<String, dynamic> d;
  final String Function(String) statusLabel;
  final Color Function(String) statusColor;
  final void Function(Map<String, dynamic>) onOpen;

  const _DisputeMobileCard({
    required this.d,
    required this.statusLabel,
    required this.statusColor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final booking = (d['booking'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final customer = (d['customer'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final expert = (d['expert'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final payment = (d['payment'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    final createdAtStr = d['createdAt']?.toString();
    String createdShort = '';
    if (createdAtStr != null) {
      try {
        final dt = DateTime.parse(createdAtStr);
        createdShort =
            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        createdShort = createdAtStr;
      }
    }

    final amount = payment['amount'] ?? 0;
    final currency = payment['currency'] ?? 'USD';
    final status = (d['status'] ?? '').toString();
    final type = (d['type'] ?? '').toString();

    return _SurfaceCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  booking['code'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                ),
              ),
              _StatusChip(label: statusLabel(status), color: statusColor(status)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _MiniInfo(icon: Icons.calendar_today_outlined, text: createdShort.isEmpty ? '-' : createdShort),
              const SizedBox(width: 10),
              _MiniInfo(icon: Icons.payments_outlined, text: '$amount $currency'),
            ],
          ),
          const SizedBox(height: 10),
          _Line(label: 'Customer', value: '${customer['name'] ?? '-'}  •  ${customer['email'] ?? ''}'),
          const SizedBox(height: 6),
          _Line(label: 'Expert', value: '${expert['name'] ?? '-'}  •  ${expert['email'] ?? ''}'),
          const SizedBox(height: 6),
          _Line(label: 'Type', value: type),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onOpen(d),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('View / Decide'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;

  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontSize: 12.5, color: Colors.grey.shade700, fontWeight: FontWeight.w700);
    final valueStyle = const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 76, child: Text(label, style: labelStyle)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: valueStyle)),
      ],
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
      ],
    );
  }
}

/*────────────────────────  Status Chip  ────────────────────────*/

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }
}

/*────────────────────────  Stat Card  ────────────────────────*/

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
      width: 220,
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
        border: Border.all(color: const Color(0xFFE8EDF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
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
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/*────────────────────────  Chart Card + Donut  ────────────────────────*/

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StatusDonut extends StatelessWidget {
  final int open;
  final int review;
  final int resolvedCustomer;
  final int resolvedExpert;
  final Color primary;

  const _StatusDonut({
    required this.open,
    required this.review,
    required this.resolvedCustomer,
    required this.resolvedExpert,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final total = open + review + resolvedCustomer + resolvedExpert;
    final openC = const Color(0xFFEB5757);
    final reviewC = const Color(0xFFF2C94C);
    final rcC = const Color(0xFF27AE60);
    final reC = const Color(0xFF2D9CDB);

    return LayoutBuilder(
      builder: (context, c) {
        // ✅ Fix: لو المساحة ضيقة، اعرض chart فوق والـ legend تحت (ما يصير نص عمودي)
        final stackMode = c.maxWidth < 520;

        final donutSize = math.min(stackMode ? c.maxWidth : 260.0, 260.0).clamp(180.0, 260.0);

        final donut = SizedBox(
          width: donutSize,
          height: donutSize,
          child: CustomPaint(
            painter: _DonutPainter(
              segments: [
                _Seg(open, openC),
                _Seg(review, reviewC),
                _Seg(resolvedCustomer, rcC),
                _Seg(resolvedExpert, reC),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    total.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Total',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );

        final legend = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LegendRow(color: openC, label: 'Open', value: open, total: total),
            const SizedBox(height: 8),
            _LegendRow(color: reviewC, label: 'Under review', value: review, total: total),
            const SizedBox(height: 8),
            _LegendRow(color: rcC, label: 'Resolved (customer)', value: resolvedCustomer, total: total),
            const SizedBox(height: 8),
            _LegendRow(color: reC, label: 'Resolved (expert)', value: resolvedExpert, total: total),
          ],
        );

        if (stackMode) {
          return Column(
            children: [
              Center(child: donut),
              const SizedBox(height: 14),
              legend,
            ],
          );
        }

        return Row(
          children: [
            donut,
            const SizedBox(width: 14),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final int total;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (total == 0) ? 0.0 : (value / total);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
          ),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EDF5),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

class _Seg {
  final int v;
  final Color c;
  _Seg(this.v, this.c);
}

class _DonutPainter extends CustomPainter {
  final List<_Seg> segments;
  _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<int>(0, (p, s) => p + s.v);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * 0.23;

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE8EDF5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.78),
      0,
      math.pi * 2,
      false,
      basePaint,
    );

    if (total == 0) return;

    double start = -math.pi / 2;
    for (final s in segments) {
      if (s.v <= 0) continue;
      final sweep = (s.v / total) * math.pi * 2;

      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = s.c;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.78),
        start,
        sweep,
        false,
        p,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    if (oldDelegate.segments.length != segments.length) return true;
    for (int i = 0; i < segments.length; i++) {
      if (oldDelegate.segments[i].v != segments[i].v) return true;
      if (oldDelegate.segments[i].c != segments[i].c) return true;
    }
    return false;
  }
}

/*────────────────────────  Dialog القرار (LOGIC SAME)  ────────────────────────*/

class _DisputeDecisionDialog extends StatefulWidget {
  final Map<String, dynamic> dispute;

  const _DisputeDecisionDialog({required this.dispute});

  @override
  State<_DisputeDecisionDialog> createState() => _DisputeDecisionDialogState();
}

class _DisputeDecisionDialogState extends State<_DisputeDecisionDialog> {
  late String _resolution;
  late TextEditingController _refundController;
  late TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final dispute = widget.dispute;

    _resolution = (dispute['resolution'] ?? 'NONE').toString();
    if (_resolution == 'NONE') _resolution = 'NO_REFUND';

    final refundAmount = (dispute['refundAmount'] ?? 0).toString();
    _refundController = TextEditingController(text: refundAmount == '0' ? '' : refundAmount);
    _notesController = TextEditingController(text: dispute['adminNotes']?.toString() ?? '');
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

  // ✅ LOGIC (NO CHANGES)
  Future<void> _saveDecision() async {
    final dispute = widget.dispute;

    final payment = (dispute['payment'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    double? refundAmount;

    if (_resolution == 'REFUND_PARTIAL') {
      refundAmount = double.tryParse(_refundController.text.trim());
      if (refundAmount == null || refundAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid partial refund amount')),
        );
        return;
      }
    } else if (_resolution == 'REFUND_FULL') {
      final total = (payment['amount'] ?? 0).toDouble();
      refundAmount = total;
    } else {
      refundAmount = 0;
    }

    setState(() => _saving = true);

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute decision saved')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const Color accent = Color(0xFF285E6E);

  @override
  Widget build(BuildContext context) {
    final dispute = widget.dispute;

    final booking = (dispute['booking'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final customer = (dispute['customer'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final expert = (dispute['expert'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final payment = (dispute['payment'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final attachments = (dispute['attachments'] as List?)?.cast<String>() ?? <String>[];

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, minHeight: 520),
        child: LayoutBuilder(
          builder: (context, c) {
            final isMobile = c.maxWidth < 860;

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'Summary'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoTile(title: 'Booking', lines: ['Code: ${booking['code'] ?? '-'}', 'Status: ${booking['status'] ?? '-'}']),
                    _InfoTile(title: 'Customer', lines: [customer['name'] ?? '-', customer['email'] ?? '']),
                    _InfoTile(title: 'Expert', lines: [expert['name'] ?? '-', expert['email'] ?? '']),
                    _InfoTile(
                      title: 'Payment',
                      lines: [
                        'Amount: ${payment['amount'] ?? 0} ${payment['currency'] ?? 'USD'}',
                        'Status: ${payment['status'] ?? '-'}',
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Customer message'),
                const SizedBox(height: 8),
                _SoftBox(
                  child: Text(
                    dispute['customerMessage']?.toString() ?? '',
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Attachments'),
                const SizedBox(height: 8),
                attachments.isEmpty
                    ? Text(
                        'No attachments provided.',
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: attachments.map((url) {
                          final fileName = Uri.parse(url).pathSegments.isEmpty ? 'Attachment' : Uri.parse(url).pathSegments.last;
                          return ActionChip(
                            onPressed: () => _openAttachment(url),
                            avatar: const Icon(Icons.attach_file, size: 18),
                            label: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: Text(fileName, overflow: TextOverflow.ellipsis),
                            ),
                          );
                        }).toList(),
                      ),
              ],
            );

            final decision = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(title: 'Admin decision'),
                const SizedBox(height: 10),
                _SoftBox(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _resolution,
                        decoration: const InputDecoration(
                          labelText: 'Resolution',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'NO_REFUND', child: Text('No refund')),
                          DropdownMenuItem(value: 'REFUND_FULL', child: Text('Full refund')),
                          DropdownMenuItem(value: 'REFUND_PARTIAL', child: Text('Partial refund')),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) {
                                if (v != null) setState(() => _resolution = v);
                              },
                      ),
                      const SizedBox(height: 12),
                      if (_resolution == 'REFUND_PARTIAL')
                        TextFormField(
                          controller: _refundController,
                          decoration: const InputDecoration(
                            labelText: 'Partial amount',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          enabled: !_saving,
                        ),
                      if (_resolution == 'REFUND_PARTIAL') const SizedBox(height: 12),
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
              ],
            );

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    color: Color(0xFFF4F7FB),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.gavel_outlined, color: accent),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Dispute details & decision',
                          style: TextStyle(fontWeight: FontWeight.w900, color: accent),
                        ),
                      ),
                      IconButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SingleChildScrollView(
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                details,
                                const SizedBox(height: 16),
                                const Divider(),
                                const SizedBox(height: 12),
                                decision,
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: details),
                                const SizedBox(width: 14),
                                Expanded(flex: 4, child: decision),
                              ],
                            ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
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
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/*────────────────────────  Dialog UI Helpers  ────────────────────────*/

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        color: Color(0xFF285E6E),
        fontSize: 13.5,
      ),
    );
  }
}

class _SoftBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SoftBox({
    required this.child,
    this.padding = const EdgeInsets.all(10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE0E6F0)),
      ),
      child: child,
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final List<String> lines;

  const _InfoTile({required this.title, required this.lines});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
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
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          ...lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                l,
                style: const TextStyle(fontSize: 12.7, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}