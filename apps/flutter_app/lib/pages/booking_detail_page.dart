// lib/pages/booking_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // ⭐ مهم لفتح Zoom

class BookingDetailPage extends StatefulWidget {
  final String bookingId;
  const BookingDetailPage({super.key, required this.bookingId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  static const baseUrl = 'http://localhost:5000/api';
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

      // ⚠️ في حالة وجود خطأ (مثل تعارض المواعيد أو فشل آخر)
      if (res.statusCode >= 400) {
        String msg = 'Something went wrong.';
        try {
          final j = jsonDecode(res.body);
          msg = j['error'] ?? msg;
        } catch (_) {}

        // 🔴 عرض Dialog واضح للخطأ
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: const Text(
                "Error",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
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

      // ✅ نجاح العملية → أعد تحميل الحجز
      await _load();

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      // 🛜 خطأ في الاتصال بالشبكة
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            title: const Text(
              "Network Error",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            content: Text(
                "Please check your internet connection.\n\nDetails: $e"),
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

  // ✅ فتح لينك Zoom من الحجز (startUrl للخبير، ولو مش موجود نستخدم joinUrl)
  Future<void> _openMeetingLinkFromBooking(Map<String, dynamic> b) async {
    final meeting =
        (b['meeting'] ?? {}) as Map<String, dynamic>;

    final urlStr = (meeting['startUrl'] ??
            meeting['joinUrl'] ??
            '')
        .toString()
        .trim();

    if (urlStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "No Zoom meeting link available for this booking."),
          ),
        );
      }
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Invalid meeting URL."),
          ),
        );
      }
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not open meeting link."),
        ),
      );
    }
  }

  // ✅ زر Start: يغيّر الحالة لـ IN_PROGRESS ثم يفتح Zoom
  Future<void> _startBookingAndOpenMeeting(
      Map<String, dynamic> b) async {
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: const Text(
                "Error",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
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
      final updated =
          Map<String, dynamic>.from(body['booking'] as Map);

      // حدّث الـ state
      if (mounted) {
        setState(() {
          booking = updated;
        });
      }

      // 🎥 افتح لينك Zoom
      await _openMeetingLinkFromBooking(updated);
    } catch (e) {
      if (mounted) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            title: const Text(
              "Network Error",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
            content: Text(
                "Please check your internet connection.\n\nDetails: $e"),
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

  // ✅ Dialog بعد تحديث الحالة من _action
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          title: const Text(
            "Success",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content:
              const Text("The booking status was updated successfully."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // إغلاق الـ Dialog
                Navigator.pop(context,
                    true); // الرجوع للصفحة السابقة + تحديث
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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final b = booking!;
    final status = b['status'];
    final primaryColor = const Color(0xFF62C6D9);

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(b['code'] ?? 'Booking'),
        backgroundColor: primaryColor,
        elevation: 2,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statusHeader(status),
              const SizedBox(height: 20),

              // ===== المعلومات الأساسية =====
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.6,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                children: [
                  _Section(
                    title: "Client",
                    icon: Icons.person,
                    child: Text(
                        '${b['customer']?['name']} • ${b['customer']?['email']}'),
                  ),
                  _Section(
                    title: "Service",
                    icon: Icons.work,
                    child: Text(
                        '${b['serviceSnapshot']?['title']} • ${b['serviceSnapshot']?['durationMinutes']} min'),
                  ),
                  _Section(
                    title: "Schedule",
                    icon: Icons.date_range,
                    child: Text(
                      'Start: ${b['startAt']}\nEnd: ${b['endAt']}\nTZ: ${b['timezone']}',
                    ),
                  ),
                  _Section(
                    title: "Payment",
                    icon: Icons.payment,
                    child: Text(
                        '${b['payment']?['status']} • ${b['payment']?['amount']} ${b['payment']?['currency']}'),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 🟣 معلومات الميتنج (اختياري لعرض Zoom Info)
              if ((b['meeting'] ?? {}) is Map &&
                  ((b['meeting'] as Map)['joinUrl'] != null ||
                      (b['meeting'] as Map)['startUrl'] != null))
                _Section(
                  title: "Meeting",
                  icon: Icons.videocam,
                  child: Builder(
                    builder: (ctx) {
                      final m = b['meeting'] as Map;
                      final provider =
                          (m['provider'] ?? 'ZOOM').toString();
                      final meetingId =
                          (m['meetingId'] ?? '').toString();
                      final shortUrl =
                          (m['joinUrl'] ?? m['startUrl'] ?? '')
                              .toString();
                      final displayUrl = shortUrl.length > 40
                          ? '${shortUrl.substring(0, 40)}...'
                          : shortUrl;

                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text('Provider: $provider'),
                          if (meetingId.isNotEmpty)
                            Text('Meeting ID: $meetingId'),
                          if (shortUrl.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              displayUrl,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 14),
              _Section(
                title: "Notes",
                icon: Icons.sticky_note_2,
                child: Text(b['notes'] ?? '-'),
              ),

              const SizedBox(height: 20),
              _actionButtons(status, b, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusHeader(String status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.blueAccent),
          const SizedBox(width: 12),
          const Text(
            "Current Status: ",
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _statusColor(status),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
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
      default:
        return Colors.grey;
    }
  }

  Widget _actionButtons(
      String status, Map<String, dynamic> b, Color primaryColor) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (status == 'PENDING') ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                _action('/expert/bookings/${b['_id']}/accept'),
            child: const Text('Accept'),
          ),
          OutlinedButton(
            onPressed: () =>
                _action('/expert/bookings/${b['_id']}/decline'),
            child: const Text('Decline'),
          ),
        ],
        if (status == 'CONFIRMED') ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            // ⭐ الآن: Start → يغيّر الحالة ويفتح Zoom
            onPressed: () => _startBookingAndOpenMeeting(b),
            child: const Text('Start'),
          ),
        ],
        if (status == 'IN_PROGRESS') ...[
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () =>
                _action('/expert/bookings/${b['_id']}/complete'),
            child: const Text('Complete'),
          ),
          TextButton(
            onPressed: () =>
                _action('/expert/bookings/${b['_id']}/no-show'),
            child: const Text('No-Show'),
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final IconData icon;

  const _Section(
      {required this.title, required this.child, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blueGrey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}