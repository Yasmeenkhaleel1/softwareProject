//customer_calendar_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';

class CustomerCalendarPage extends StatefulWidget {
  const CustomerCalendarPage({super.key});

  @override
  State<CustomerCalendarPage> createState() => _CustomerCalendarPageState();
}

class _CustomerCalendarPageState extends State<CustomerCalendarPage> {
  bool _loading = true;
  String? _error;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Map<String, dynamic>> _allBookings = [];
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<String?> _customerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  DateTime _dayKey(DateTime d) =>
      DateTime(d.year, d.month, d.day); // بدون وقت

  Future<void> _loadBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cid = await _customerId();
      if (cid == null) {
        setState(() {
          _error = "Please login to see your calendar.";
          _loading = false;
        });
        return;
      }

      // نطاق الشهر الحالي
      final firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
      final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);

      final data = await ApiService.fetchCustomerBookings(
        customerId: cid,
        from: firstDay,
        to: lastDay,
      );

      _allBookings = data.map<Map<String, dynamic>>((e) {
        return (e as Map).map((k, v) => MapEntry(k.toString(), v));
      }).toList();

      _events.clear();
      for (final b in _allBookings) {
        final startAtStr = b['startAt']?.toString();
        if (startAtStr == null) continue;
        final dt = DateTime.tryParse(startAtStr);
        if (dt == null) continue;
        final key = _dayKey(dt);
        _events.putIfAbsent(key, () => []).add(b);
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _bookingsForDay(DateTime day) {
    final key = _dayKey(day);
    return _events[key] ?? [];
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "CONFIRMED":
        return const Color(0xFF27AE60);
      case "IN_PROGRESS":
        return const Color(0xFF2D9CDB);
      case "COMPLETED":
        return const Color(0xFF9B51E0);
      case "CANCELED":
      case "NO_SHOW":
        return const Color(0xFFEB5757);
      case "PENDING":
      default:
        return const Color(0xFFF2C94C);
    }
  }

  Future<void> _joinSession(Map<String, dynamic> booking) async {
    final meeting = (booking['meeting'] ?? {}) as Map<String, dynamic>;
    final urlStr =
        (meeting['joinUrl'] ?? meeting['meetingUrl'] ?? '').toString().trim();

    if (urlStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No meeting link available for this booking."),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid meeting URL."),
        ),
      );
      return;
    }

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Could not open meeting link."),
        ),
      );
    }
  }

  Future<void> _openRatingDialog(Map<String, dynamic> booking) async {
    final service = (booking['service'] ?? {}) as Map<String, dynamic>;
    final serviceTitle = (service['title'] ?? 'Service').toString();
    final currentReview =
        (booking['review'] ?? {}) as Map<String, dynamic>? ?? {};

    int rating = (currentReview['rating'] ?? 5) as int;
    final TextEditingController commentCtrl = TextEditingController(
      text: currentReview['comment']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            "Rate $serviceTitle",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("How was your session?"),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final starIndex = i + 1;
                  final filled = starIndex <= rating;
                  return IconButton(
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? Colors.amber : Colors.grey,
                    ),
                    onPressed: () {
                      rating = starIndex;
                      (ctx as Element).markNeedsBuild();
                    },
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Comment (optional)",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    try {
      await ApiService.submitBookingReview(
        bookingId: booking['id'].toString(),
        rating: rating,
        comment: commentCtrl.text.trim().isEmpty
            ? null
            : commentCtrl.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thank you for your review!")),
      );

      // 🔁 أعد تحميل البيانات لتحديث النجوم في الصفحة
      await _loadBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit review: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF285E6E);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text(
          "My Calendar",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                )
              : Column(
                  children: [
                    // 🔹 Calendar
                    Card(
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TableCalendar(
                          firstDay: DateTime.utc(2020, 1, 1),
                          lastDay: DateTime.utc(2100, 12, 31),
                          focusedDay: _focusedDay,
                          calendarFormat: CalendarFormat.month,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          selectedDayPredicate: (day) =>
                              isSameDay(_selectedDay, day),
                          eventLoader: (day) => _bookingsForDay(day),
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                            _loadBookings();
                          },
                          calendarStyle: const CalendarStyle(
                            markerDecoration: BoxDecoration(
                              color: primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          headerStyle: const HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                          ),
                        ),
                      ),
                    ),

                    // 🔹 قائمة حجوزات اليوم
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.event_note,
                              size: 18, color: primary),
                          const SizedBox(width: 6),
                          Text(
                            "Bookings on "
                            "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    Expanded(
                      child: _buildBookingListForSelectedDay(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildBookingListForSelectedDay() {
    final bookings = _bookingsForDay(_selectedDay);

    if (bookings.isEmpty) {
      return const Center(
        child: Text(
          "No bookings on this day.",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final b = bookings[index];
        final service = (b['service'] ?? {}) as Map<String, dynamic>;
        final expert = (b['expert'] ?? {}) as Map<String, dynamic>;
        final review = (b['review'] ?? {}) as Map<String, dynamic>;
        final status = b['status']?.toString() ?? '';

        final title = (service['title'] ?? 'Service').toString();
        final expertName = (expert['name'] ?? 'Expert').toString();

        final startAtStr = b['startAt']?.toString();
        final endAtStr = b['endAt']?.toString();
        DateTime? s, e;
        if (startAtStr != null) s = DateTime.tryParse(startAtStr);
        if (endAtStr != null) e = DateTime.tryParse(endAtStr);

        final timeLabel = (s != null && e != null)
            ? "${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')} - "
              "${e.hour.toString().padLeft(2, '0')}:${e.minute.toString().padLeft(2, '0')}"
            : "";

        final canJoin = ["CONFIRMED", "IN_PROGRESS"]
            .contains(status.toUpperCase());
        final canRate = status == "COMPLETED";

        final ratingValue = (review['rating'] ?? 0) as int;

        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // العنوان + الحالة
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
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
                const SizedBox(height: 4),
                Text(
                  "with $expertName",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                if (timeLabel.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                Row(
                  children: [
                    if (canJoin)
                      ElevatedButton.icon(
                        onPressed: () => _joinSession(b),
                        icon: const Icon(Icons.videocam, size: 18),
                        label: const Text("Join session"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF62C6D9),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (canJoin) const SizedBox(width: 8),
                    if (canRate)
                      TextButton.icon(
                        onPressed: () => _openRatingDialog(b),
                        icon: const Icon(Icons.star_border),
                        label: Text(
                          ratingValue > 0 ? "Edit review" : "Rate service",
                        ),
                      ),
                  ],
                ),

                if (ratingValue > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: List.generate(5, (i) {
                      final filled = i + 1 <= ratingValue;
                      return Icon(
                        filled ? Icons.star : Icons.star_border,
                        size: 16,
                        color: filled ? Colors.amber : Colors.grey,
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
