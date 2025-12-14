// lib/pages/my_booking_tab.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/bookings_provider.dart';
import '../../models/booking.dart';
import 'booking_detail_page.dart';

class MyBookingTab extends StatefulWidget {
  const MyBookingTab({super.key});

  @override
  State<MyBookingTab> createState() => _MyBookingTabState();
}

class _MyBookingTabState extends State<MyBookingTab> {
  String? statusFilter;
  DateTimeRange? range;

  int page = 1;
  final int limit = 10;

  final statuses = const [
    null,
    'PENDING',
    'CONFIRMED',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELED',
    'NO_SHOW'
  ];

  final mainColor = const Color(0xFF62C6D9);

  bool get isMobile => MediaQuery.of(context).size.width < 768;

  // ================= PREFS =================
  Future<void> _loadPrefsAndFetch() async {
    final p = await SharedPreferences.getInstance();
    final savedStatus = p.getString('mb_status');
    final startIso = p.getString('mb_range_start');
    final endIso = p.getString('mb_range_end');

    if (!mounted) return;

    setState(() {
      statusFilter = savedStatus == 'null' ? null : savedStatus;
      if (startIso != null && endIso != null) {
        range = DateTimeRange(
          start: DateTime.parse(startIso),
          end: DateTime.parse(endIso),
        );
      }
    });

    _fetch();
  }

  Future<void> _persistFilters() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('mb_status', statusFilter?.toString() ?? 'null');

    if (range == null) {
      await p.remove('mb_range_start');
      await p.remove('mb_range_end');
    } else {
      await p.setString('mb_range_start', range!.start.toIso8601String());
      await p.setString('mb_range_end', range!.end.toIso8601String());
    }
  }

  void clearRange() {
    setState(() => range = null);
    _persistFilters();
  }

  void _fetch() {
    context.read<BookingsProvider>().fetch(
          status: statusFilter,
          from: range?.start,
          to: range?.end,
          page: page,
          limit: limit,
        );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrefsAndFetch();
    });
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Consumer<BookingsProvider>(
      builder: (context, bp, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: mainColor,
            title: const Text(
              "My Bookings",
              style: TextStyle(color: Colors.white),
            ),
            elevation: 2,
            iconTheme: const IconThemeData(color: Colors.white),

            // ✅ FIXED Drawer opening
          leading: isMobile
    ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      )
    : null,

actions: isMobile
    ? [
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ]
    : null,
   ),
          // ✅ Mobile Drawer
          drawer: isMobile ? _buildMobileDrawer(context, bp) : null,

          body: isMobile
              ? _buildMobileLayout(context, bp)
              : _buildDesktopLayout(context, bp),
        );
      },
    );
  }

  // ================= DESKTOP =================
  Widget _buildDesktopLayout(BuildContext context, BookingsProvider bp) {
    return Row(
      children: [
        _buildDesktopSidebar(bp),
        Expanded(child: _buildMainContent(bp, isMobile: false)),
      ],
    );
  }

  // ================= MOBILE =================
  Widget _buildMobileLayout(BuildContext context, BookingsProvider bp) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _buildMainContent(bp, isMobile: true),
    );
  }

  // ================= MAIN CONTENT =================
  Widget _buildMainContent(BookingsProvider bp, {required bool isMobile}) {
    return Column(
      children: [
        const _OverviewHeader(),
        const SizedBox(height: 16),

        _Filters(
          status: statusFilter,
          onStatusChanged: (s) {
            setState(() {
              statusFilter = s;
              page = 1;
            });
            _persistFilters();
          },
          onApply: () {
            _persistFilters();
            _fetch();
          },
          onPickRange: (r) {
            setState(() => range = r);
            _persistFilters();
          },
          onClearRange: () {
            clearRange();
            _fetch();
          },
          rangeLabel: _rangeLabel(range, context),
          currentRange: range,
          isMobile: isMobile,
        ),

        const SizedBox(height: 16),

        Expanded(
          child: bp.loading
              ? const _LoadingList()
              : bp.items.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: bp.items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final b = bp.items[i];
                        return _BookingTile(
                          b: b,
                          onChanged: _fetch,
                          isMobile: isMobile,
                        );
                      },
                    ),
        ),

        if (!bp.loading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Total: ${bp.items.length} bookings',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  // ================= SIDEBARS =================
  Widget _buildDesktopSidebar(BookingsProvider bp) {
    return Container(
      width: 220,
      color: mainColor,
      child: _buildSidebarContent(bp, closeOnTap: false),
    );
  }

  Widget _buildMobileDrawer(BuildContext context, BookingsProvider bp) {
    return Drawer(
      backgroundColor: mainColor,
      child: SafeArea(
        child: _buildSidebarContent(bp, closeOnTap: true),
      ),
    );
  }

  Widget _buildSidebarContent(BookingsProvider bp,
      {required bool closeOnTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Status",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, num>>(
            future: context.read<BookingsProvider>().overview(),
            builder: (context, snap) {
              final counts = snap.data ?? {};
              return ListView(
                children: statuses.map((s) {
                  final selected = statusFilter == s;
                  final label = s ?? "All";
                  final count = _countFor(label, counts);

                  return InkWell(
                    onTap: () {
                      setState(() {
                        statusFilter = s;
                        page = 1;
                      });
                      _persistFilters();
                      _fetch();
                      if (closeOnTap) Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(0.22)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${count ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= HELPERS =================
  num? _countFor(String label, Map<String, num> m) {
    switch (label) {
      case 'All':
        return ['PENDING', 'CONFIRMED', 'IN_PROGRESS', 'COMPLETED']
            .fold<num>(0, (a, k) => a + (m[k] ?? 0));
      default:
        return m[label] ?? 0;
    }
  }

  String _rangeLabel(DateTimeRange? r, BuildContext context) {
    if (r == null) return 'No date range';
    final l = MaterialLocalizations.of(context);
    return '${l.formatMediumDate(r.start)} → ${l.formatMediumDate(r.end)}';
  }
}

// ================= باقي الكلاسات بدون أي حذف =================

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    final theme = Theme.of(context);

    return FutureBuilder<Map<String, num>>(
      future: context.read<BookingsProvider>().overview(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return SizedBox(
            height: isMobile ? 80 : 90,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final m = snap.data!;
        Widget stat(String label, String key, IconData icon, Color color) {
          final v = m[key] ?? 0;
          return Container(
            width: isMobile ? 200 : null,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.28)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.bold)),
                    Text(
                      "$v",
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        }

        return isMobile
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    stat("Pending", "PENDING", Icons.schedule, Colors.amber),
                    const SizedBox(width: 8),
                    stat("Confirmed", "CONFIRMED",
                        Icons.check_circle, Colors.blueAccent),
                    const SizedBox(width: 8),
                    stat("In Progress", "IN_PROGRESS",
                        Icons.timelapse, Colors.orange),
                    const SizedBox(width: 8),
                    stat("Completed", "COMPLETED",
                        Icons.done_all, Colors.green),
                  ],
                ),
              )
            : Row(
                children: [
                  Expanded(child: stat("Pending", "PENDING", Icons.schedule, Colors.amber)),
                  const SizedBox(width: 12),
                  Expanded(child: stat("Confirmed", "CONFIRMED", Icons.check_circle, Colors.blueAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: stat("In Progress", "IN_PROGRESS", Icons.timelapse, Colors.orange)),
                  const SizedBox(width: 12),
                  Expanded(child: stat("Completed", "COMPLETED", Icons.done_all, Colors.green)),
                ],
              );
      },
    );
  }
}

// باقي الكلاسات (_Filters, _BookingTile, _EmptyState, _LoadingList, ShimmerTile)

class _Filters extends StatelessWidget {
  final String? status;
  final void Function(String?) onStatusChanged;
  final void Function() onApply;
  final void Function(DateTimeRange) onPickRange;
  final void Function() onClearRange;
  final String rangeLabel;
  final DateTimeRange? currentRange;
  final bool isMobile;

  const _Filters({
    required this.status,
    required this.onStatusChanged,
    required this.onApply,
    required this.onPickRange,
    required this.onClearRange,
    required this.rangeLabel,
    required this.currentRange,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          Card(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  DropdownButtonFormField<String?>(
                    decoration: const InputDecoration(labelText: "Status"),
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: null, child: Text("All")),
                      DropdownMenuItem(value: "PENDING", child: Text("Pending")),
                      DropdownMenuItem(value: "CONFIRMED", child: Text("Confirmed")),
                      DropdownMenuItem(value: "IN_PROGRESS", child: Text("In Progress")),
                      DropdownMenuItem(value: "COMPLETED", child: Text("Completed")),
                      DropdownMenuItem(value: "CANCELED", child: Text("Canceled")),
                      DropdownMenuItem(value: "NO_SHOW", child: Text("No Show")),
                    ],
                    onChanged: onStatusChanged,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.date_range),
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDateRangePicker(
                              context: context,
                              initialDateRange: currentRange ??
                                  DateTimeRange(
                                    start: now,
                                    end: now.add(const Duration(days: 1)),
                                  ),
                              firstDate: DateTime(now.year - 1),
                              lastDate: DateTime(now.year + 1),
                            );
                            if (picked != null) onPickRange(picked);
                          },
                          label: Text(
                            rangeLabel,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (rangeLabel != "No date range")
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.redAccent),
                          onPressed: onClearRange,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: onApply,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Apply Filters'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                decoration: const InputDecoration(labelText: "Status"),
                initialValue: status,
                items: const [
                  DropdownMenuItem(value: null, child: Text("All")),
                  DropdownMenuItem(value: "PENDING", child: Text("Pending")),
                  DropdownMenuItem(value: "CONFIRMED", child: Text("Confirmed")),
                  DropdownMenuItem(value: "IN_PROGRESS", child: Text("In Progress")),
                  DropdownMenuItem(value: "COMPLETED", child: Text("Completed")),
                  DropdownMenuItem(value: "CANCELED", child: Text("Canceled")),
                  DropdownMenuItem(value: "NO_SHOW", child: Text("No Show")),
                ],
                onChanged: onStatusChanged,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDateRangePicker(
                  context: context,
                  initialDateRange: currentRange ??
                      DateTimeRange(
                        start: now,
                        end: now.add(const Duration(days: 1)),
                      ),
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 1),
                  builder: (context, child) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 640,
                          maxHeight: 520,
                        ),
                        child: Material(
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: child!,
                        ),
                      ),
                    );
                  },
                );
                if (picked != null) onPickRange(picked);
              },
              label: Text(rangeLabel),
            ),
            if (rangeLabel != "No date range")
              Tooltip(
                message: 'Clear date',
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  onPressed: onClearRange,
                ),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.filter_alt),
              label: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking b;
  final VoidCallback onChanged;
  final bool isMobile;

  const _BookingTile({
    required this.b,
    required this.onChanged,
    this.isMobile = false,
  });

  Color _badgeColor(String s) {
    switch (s) {
      case 'CONFIRMED':
        return Colors.blueAccent;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELED':
      case 'NO_SHOW':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _badgeColor(b.status);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: color.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
              blurRadius: 4,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingDetailPage(bookingId: b.id),
              ),
            );

            if (updated == true) {
              onChanged();
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.15),
                radius: isMobile ? 18 : 20,
                child: Icon(
                  Icons.event,
                  color: color,
                  size: isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.service?['title'] ?? 'Service',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${b.customer?['name'] ?? ''} • ${b.code}',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: isMobile ? 12 : 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  b.status,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                backgroundColor: color.withOpacity(0.18),
                labelStyle: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.inbox, size: 62, color: Colors.grey),
        SizedBox(height: 10),
        Text(
          "No bookings found.",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 4),
        Text(
          "Try adjusting your filters",
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: isMobile ? 3 : 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => ShimmerTile(isMobile: isMobile),
    );
  }
}

class ShimmerTile extends StatelessWidget {
  final bool isMobile;
  const ShimmerTile({super.key, this.isMobile = false});

  @override
  Widget build(BuildContext context) {
    final base = Colors.grey.withOpacity(0.25);
    return Container(
      height: isMobile ? 60 : 70,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}