// lib/pages/booking_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // ⭐ مهم لفتح Zoom

import '../config/api_config.dart'; // ✅ فقط لتصحيح baseUrl على الويب/الموبايل

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  // ✅ نفس اللوجيك (كما هو) — فقط baseUrl صار ديناميكي ليدعم Web/Mobile
  static String get baseUrl => "${ApiConfig.baseUrl}/api";

  Map<String, dynamic>? booking;
  bool loading = true;
  String? error;

  Future<String?> _token() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('token');
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final t = await _token();
      final res = await http.get(
        Uri.parse('$baseUrl/expert/bookings/${widget.bookingId}'),
        headers: {'Authorization': 'Bearer $t'},
      );
      if (res.statusCode != 200) throw Exception('Failed');
      final j = jsonDecode(res.body);
      booking = Map<String, dynamic>.from(j['booking'] as Map);
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _action(String path, {Map<String, dynamic>? body}) async {
    final t = await _token();

    try {
      final res = await http.post(
        Uri.parse('$baseUrl$path'),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body ?? {}),
      );

      if (res.statusCode >= 400) {
        String msg = 'Something went wrong.';
        try {
          final j = jsonDecode(res.body);
          msg = j['error'] ?? msg;
        } catch (_) {}

        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text(
                "Error",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _load();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              "Network Error",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
            ),
            content: Text("Please check your internet connection.\n\nDetails: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _openMeetingLinkFromBooking(Map<String, dynamic> b) async {
    final meeting = (b['meeting'] ?? {}) as Map<String, dynamic>;

    final urlStr = (meeting['startUrl'] ?? meeting['joinUrl'] ?? '').toString().trim();

    if (urlStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No Zoom meeting link available for this booking.")),
        );
      }
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid meeting URL.")),
        );
      }
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open meeting link.")),
      );
    }
  }

  Future<void> _startBookingAndOpenMeeting(Map<String, dynamic> b) async {
    final t = await _token();

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/expert/bookings/${b['_id']}/start'),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );

      if (res.statusCode >= 400) {
        String msg = 'Something went wrong.';
        try {
          final j = jsonDecode(res.body);
          msg = j['error'] ?? msg;
        } catch (_) {}

        if (mounted) {
          await showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: const Text(
                "Error",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
              ),
              content: Text(msg),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final updated = Map<String, dynamic>.from(body['booking'] as Map);

      if (mounted) {
        setState(() {
          booking = updated;
        });
      }

      await _openMeetingLinkFromBooking(updated);
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Text(
              "Network Error",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orangeAccent),
            ),
            content: Text("Please check your internet connection.\n\nDetails: $e"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text("Success", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("The booking status was updated successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, true);
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ===================== UI helpers (Design only) =====================
  static const Color _primary = Color(0xFF62C6D9);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  bool get _isWebWide => MediaQuery.of(context).size.width >= 1024;
  bool get _isMobile => MediaQuery.of(context).size.width < 760;
  bool get _isVeryNarrow => MediaQuery.of(context).size.width < 380;

  TextStyle get _h1 => TextStyle(
        fontSize: _isWebWide ? 26 : 20,
        fontWeight: FontWeight.w900,
        color: _ink,
      );

  TextStyle get _h2 => TextStyle(
        fontSize: _isWebWide ? 16 : 14,
        fontWeight: FontWeight.w900,
        color: _ink,
      );

  TextStyle get _p => TextStyle(
        fontSize: _isWebWide ? 14.5 : 13.5,
        height: 1.45,
        color: _ink.withOpacity(0.90),
      );

  String _fmtDate(dynamic v) {
    final s = (v ?? '').toString().trim();
    if (s.isEmpty) return '-';
    final dt = DateTime.tryParse(s);
    if (dt == null) return s;
    final l = MaterialLocalizations.of(context);
    final d = l.formatMediumDate(dt.toLocal());
    final t = l.formatTimeOfDay(TimeOfDay.fromDateTime(dt.toLocal()));
    return "$d • $t";
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'CONFIRMED':
        return Colors.blueAccent;
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'CANCELED':
        return Colors.redAccent;
      case 'NO_SHOW':
        return Colors.redAccent;
      case 'PENDING':
        return Colors.amber.shade800;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'CONFIRMED':
        return Icons.check_circle_outline;
      case 'IN_PROGRESS':
        return Icons.timelapse;
      case 'COMPLETED':
        return Icons.done_all;
      case 'CANCELED':
        return Icons.cancel_outlined;
      case 'NO_SHOW':
        return Icons.person_off_outlined;
      case 'PENDING':
        return Icons.schedule;
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          booking?['code']?.toString() ?? 'Booking',
          maxLines: 1,
          overflow: TextOverflow.ellipsis, // ✅ منع overflow بالـ title
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: _isWebWide ? 18 : 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : (error != null)
                ? Center(
                    child: _SaasCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 34),
                            const SizedBox(height: 10),
                            const Text("Failed to load booking", style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _load,
                              style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                              icon: const Icon(Icons.refresh),
                              label: const Text("Try again"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final b = booking!;
    final status = (b['status'] ?? '').toString();
    final statusColor = _statusColor(status);

    final maxWidth = _isWebWide ? 1180.0 : 980.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, _isWebWide ? 18 : 14, 16, 24),
          children: [
            // ====== Top summary header (SaaS) ======
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 8),
                  child: child,
                ),
              ),
              child: _SaasCard(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: statusColor.withOpacity(0.22)),
                        ),
                        child: Icon(_statusIcon(status), color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Booking overview", style: _h1),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _Pill(
                                  icon: Icons.confirmation_number_outlined,
                                  label: "Code",
                                  value: (b['code'] ?? '-').toString(),
                                  color: _primary,
                                ),
                                _Pill(
                                  icon: _statusIcon(status),
                                  label: "Status",
                                  value: status,
                                  color: statusColor,
                                ),
                                _Pill(
                                  icon: Icons.public,
                                  label: "Timezone",
                                  value: (b['timezone'] ?? '-').toString(),
                                  color: Colors.indigo,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ====== Main grid: details + actions sidebar ======
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 980;

                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SaasCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: _ink),
                                const SizedBox(width: 8),
                                Text("Details", style: _h2),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _ResponsiveInfoGrid(
                              minTileWidth: wide ? 420 : 320,
                              isMobile: _isMobile,
                              children: [
                                _InfoTile(
                                  title: "Client",
                                  icon: Icons.person_outline,
                                  child: Text(
                                    '${b['customer']?['name'] ?? '-'} • ${b['customer']?['email'] ?? '-'}',
                                    style: _p,
                                    softWrap: true,
                                  ),
                                ),
                                _InfoTile(
                                  title: "Service",
                                  icon: Icons.work_outline,
                                  child: Text(
                                    '${b['serviceSnapshot']?['title'] ?? '-'} • ${(b['serviceSnapshot']?['durationMinutes'] ?? '-')} min',
                                    style: _p,
                                    softWrap: true,
                                  ),
                                ),
                                _InfoTile(
                                  title: "Schedule",
                                  icon: Icons.date_range_outlined,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _KVRow(k: "Start", v: _fmtDate(b['startAt']), veryNarrow: _isVeryNarrow),
                                      const SizedBox(height: 6),
                                      _KVRow(k: "End", v: _fmtDate(b['endAt']), veryNarrow: _isVeryNarrow),
                                    ],
                                  ),
                                ),
                                _InfoTile(
                                  title: "Payment",
                                  icon: Icons.payments_outlined,
                                  child: Text(
                                    '${b['payment']?['status'] ?? '-'} • ${b['payment']?['amount'] ?? '-'} ${b['payment']?['currency'] ?? ''}',
                                    style: _p,
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    if ((b['meeting'] ?? {}) is Map &&
                        ((b['meeting'] as Map)['joinUrl'] != null || (b['meeting'] as Map)['startUrl'] != null))
                      _SaasCard(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Builder(
                            builder: (ctx) {
                              final m = b['meeting'] as Map;
                              final provider = (m['provider'] ?? 'ZOOM').toString();
                              final meetingId = (m['meetingId'] ?? '').toString();
                              final shortUrl = (m['joinUrl'] ?? m['startUrl'] ?? '').toString();
                              final displayUrl =
                                  shortUrl.length > 46 ? '${shortUrl.substring(0, 46)}…' : shortUrl;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ✅ منع overflow: على الموبايل نخلي الزر تحت العنوان بدل Row ضيّق
                                  if (_isMobile)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.videocam_outlined, color: _ink),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text("Meeting", style: _h2)),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton.icon(
                                            onPressed: () => _openMeetingLinkFromBooking(b),
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text("Open link"),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _primary,
                                              side: BorderSide(color: _primary.withOpacity(0.35)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        const Icon(Icons.videocam_outlined, color: _ink),
                                        const SizedBox(width: 8),
                                        Text("Meeting", style: _h2),
                                        const Spacer(),
                                        OutlinedButton.icon(
                                          onPressed: () => _openMeetingLinkFromBooking(b),
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text("Open link"),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: _primary,
                                            side: BorderSide(color: _primary.withOpacity(0.35)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                        ),
                                      ],
                                    ),

                                  const SizedBox(height: 12),
                                  _KVRow(k: "Provider", v: provider, veryNarrow: _isVeryNarrow),
                                  if (meetingId.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    _KVRow(k: "Meeting ID", v: meetingId, veryNarrow: _isVeryNarrow),
                                  ],
                                  if (shortUrl.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      displayUrl,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis, // ✅ منع overflow للرابط
                                      style: const TextStyle(fontSize: 12.5, color: _muted),
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),
                        ),
                      ),

                    const SizedBox(height: 14),

                    _SaasCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.sticky_note_2_outlined, color: _ink),
                                const SizedBox(width: 8),
                                Text("Notes", style: _h2),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text((b['notes'] ?? '-').toString(), style: _p),
                          ],
                        ),
                      ),
                    ),
                  ],
                );

                final actions = _SaasCard(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bolt_outlined, color: _ink),
                            const SizedBox(width: 8),
                            Text("Actions", style: _h2),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Update booking status safely. Errors (conflicts, etc.) will show clearly.",
                          style: TextStyle(fontSize: _isWebWide ? 13.5 : 12.5, color: _muted, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        _actionButtons(status, b, _primary),
                      ],
                    ),
                  ),
                );

                if (!wide) {
                  return Column(
                    children: [
                      actions,
                      const SizedBox(height: 14),
                      details,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 14),
                    SizedBox(width: 360, child: actions),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ✅ نفس اللوجيك (الأزرار نفسها) بس تصميم SaaS + Icons + Responsive
  Widget _actionButtons(String status, Map<String, dynamic> b, Color primaryColor) {
    ButtonStyle filled(Color bg) => ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        );

    ButtonStyle outlined(Color c) => OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withOpacity(0.40)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        );

    final items = <Widget>[];

    if (status == 'PENDING') {
      items.addAll([
        ElevatedButton.icon(
          style: filled(primaryColor),
          onPressed: () => _action('/expert/bookings/${b['_id']}/accept'),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        OutlinedButton.icon(
          style: outlined(Colors.redAccent),
          onPressed: () => _action('/expert/bookings/${b['_id']}/decline'),
          icon: const Icon(Icons.close),
          label: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ]);
    }

    if (status == 'CONFIRMED') {
      items.add(
        ElevatedButton.icon(
          style: filled(Colors.orange),
          onPressed: () => _startBookingAndOpenMeeting(b),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Start', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
    }

    if (status == 'IN_PROGRESS') {
      items.addAll([
        ElevatedButton.icon(
          style: filled(Colors.green),
          onPressed: () => _action('/expert/bookings/${b['_id']}/complete'),
          icon: const Icon(Icons.done_all),
          label: const Text('Complete', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
        OutlinedButton.icon(
          style: outlined(Colors.redAccent),
          onPressed: () => _action('/expert/bookings/${b['_id']}/no-show'),
          icon: const Icon(Icons.person_off_outlined),
          label: const Text('No-Show', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      ]);
    }

    // Responsive arrangement
    if (_isMobile) {
      return Column(
        children: items
            .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(width: double.infinity, child: w),
                ))
            .toList(),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: items);
  }
}

// ====================== SaaS UI Components (Design only) ======================

class _SaasCard extends StatelessWidget {
  final Widget child;
  const _SaasCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 12),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Pill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ منع overflow داخل الـ pill (خصوصاً على الشاشات الضيقة)
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              "$label: ",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Colors.black.withOpacity(0.78),
              ),
            ),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KVRow extends StatelessWidget {
  final String k;
  final String v;
  final bool veryNarrow;
  const _KVRow({required this.k, required this.v, this.veryNarrow = false});

  @override
  Widget build(BuildContext context) {
    final keyW = veryNarrow ? 60.0 : 70.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: keyW,
          child: Text(
            "$k:",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _InfoTile({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6EEF8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF62C6D9).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2F8CA5), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ResponsiveInfoGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final bool isMobile;

  const _ResponsiveInfoGrid({
    required this.children,
    required this.minTileWidth,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / minTileWidth).floor().clamp(1, 3);

        // ✅ على الموبايل نزيد ارتفاع البلاطات (نقلل childAspectRatio) حتى ما يطلع overflow
        final double ratio;
        if (count == 1) {
          ratio = isMobile ? 1.85 : 2.2;
        } else if (count == 2) {
          ratio = isMobile ? 2.0 : 2.25;
        } else {
          ratio = 2.25;
        }

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: ratio,
          children: children,
        );
      },
    );
  }
}
