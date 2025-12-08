// lib/pages/customer_calendar_page.dart
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
  // --------- State ---------
  bool _loading = true;
  String? _error;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<Map<String, dynamic>> _allBookings = [];
  final Map<DateTime, List<Map<String, dynamic>>> _events = {};

  // فلتر الحالة
  String _statusFilter = 'ALL';

  // لون فيروزي عالمي للصفحة (AppBar + عناصر أخرى)
  static const Color _primary = Color(0xFF62C6D9);
  static const Color _bg = Color(0xFFF4F7FB);

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<String?> _customerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

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

      _allBookings = data
          .map<Map<String, dynamic>>(
            (e) => Map<String, dynamic>.from(e as Map),
          )
          .toList();

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
    final list = _events[key] ?? [];

    if (_statusFilter == 'ALL') return list;

    return list
        .where((b) =>
            (b['status'] ?? '').toString().toUpperCase() == _statusFilter)
        .toList();
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

  String _statusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case "CONFIRMED":
        return "Confirmed";
      case "IN_PROGRESS":
        return "In progress";
      case "COMPLETED":
        return "Completed";
      case "CANCELED":
        return "Canceled";
      case "NO_SHOW":
        return "No-show";
      case "PENDING":
        return "Pending";
      default:
        return status ?? "-";
    }
  }

  // --------- Actions ---------

  Future<void> _joinSession(Map<String, dynamic> booking) async {
    final meeting =
        (booking['meeting'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

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
    final service =
        (booking['service'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final serviceTitle = (service['title'] ?? 'Service').toString();
    final currentReview =
        (booking['review'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    int rating = (currentReview['rating'] ?? 5) as int;
    final TextEditingController commentCtrl = TextEditingController(
      text: currentReview['comment']?.toString() ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

      await _loadBookings();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit review: $e")),
      );
    }
  }

  // --------- UI ---------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _primary, // 🔹 فيروزي
        elevation: 0,
        title: const Text(
          "My Calendar",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Refresh",
            icon: const Icon(Icons.refresh),
            onPressed: _loadBookings,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 40, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    const SizedBox(height: 8),

                    // ---------- Calendar Card ----------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Column(
                            children: [
                              TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2100, 12, 31),
                                focusedDay: _focusedDay,
                                calendarFormat: CalendarFormat.month,
                                startingDayOfWeek: StartingDayOfWeek.monday,
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                eventLoader: (day) => _bookingsForDay(day),
                                onDaySelected:
                                    (selectedDay, focusedDay) async {
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
                                    color: _primary,
                                    shape: BoxShape.circle,
                                  ),
                                  todayDecoration: BoxDecoration(
                                    color: Color(0xFFEBF6F8),
                                    shape: BoxShape.circle,
                                  ),
                                  selectedDecoration: BoxDecoration(
                                    color: _primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                ),
                              ),

                              const SizedBox(height: 4),

                              // ---------- Status Filter ----------
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    const Icon(Icons.filter_list,
                                        size: 18, color: _primary),
                                    const SizedBox(width: 6),
                                    const Text(
                                      "Filter by status:",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: _primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            _buildFilterChip("All", "ALL"),
                                            _buildFilterChip(
                                                "Pending", "PENDING"),
                                            _buildFilterChip(
                                                "Confirmed", "CONFIRMED"),
                                            _buildFilterChip(
                                                "In progress", "IN_PROGRESS"),
                                            _buildFilterChip(
                                                "Completed", "COMPLETED"),
                                            _buildFilterChip(
                                                "Canceled", "CANCELED"),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ---------- Title for list ----------
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.event_note,
                              size: 18, color: _primary),
                          const SizedBox(width: 6),
                          Text(
                            "Bookings on "
                            "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---------- Booking list ----------
                    Expanded(
                      child: _buildBookingListForSelectedDay(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: selected ? Colors.white : _primary,
          ),
        ),
        selectedColor: _primary,
        backgroundColor: const Color(0xFFE0EFF3),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _statusFilter = value;
          });
        },
      ),
    );
  }

  Widget _buildBookingListForSelectedDay() {
    final bookings = _bookingsForDay(_selectedDay);

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              "No bookings on this day.",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final b = bookings[index];

        final service =
            (b['service'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final expert =
            (b['expert'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final review =
            (b['review'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

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

        final meeting =
            (b['meeting'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

        final joinUrl =
            (meeting['joinUrl'] ?? meeting['meetingUrl'] ?? '').toString().trim();

        final canJoin = ["CONFIRMED", "IN_PROGRESS"]
                .contains(status.toUpperCase()) &&
            joinUrl.isNotEmpty;

        final canRate = status == "COMPLETED";
        final ratingValue = (review['rating'] ?? 0) as int;

        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {}, // ممكن مستقبلاً تفتحي تفاصيل الحجز
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // العنوان + الحالة
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // أيقونة الخدمة
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.video_call,
                            size: 24, color: _primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
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
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(999),
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
                    ],
                  ),

                  const SizedBox(height: 10),

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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      if (canJoin) const SizedBox(width: 10),
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
                    const SizedBox(height: 6),
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
          ),
        );
      },
    );
  }
}
