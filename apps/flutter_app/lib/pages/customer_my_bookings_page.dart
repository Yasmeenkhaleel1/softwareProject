import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_service.dart';
import '../config/api_config.dart';

class CustomerMyBookingsPage extends StatefulWidget {
  const CustomerMyBookingsPage({super.key});

  @override
  State<CustomerMyBookingsPage> createState() =>
      _CustomerMyBookingsPageState();
}

class _CustomerMyBookingsPageState extends State<CustomerMyBookingsPage> {
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  bool _loading = true;
  String? _error;
  String? _myUserId;

  // كل الحجوزات الخام من الـ API
  final List<_BookingVM> _allBookings = [];

  // فلتر: ALL, UPCOMING, PAST, PENDING, COMPLETED
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getString('userId');
    await _loadBookings();
  }

  Future<void> _loadBookings() async {
    if (_myUserId == null) {
      setState(() {
        _loading = false;
        _error = "Please login to see your bookings.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await ApiService.fetchCustomerBookings(
        customerId: _myUserId!,
        // نخلي from/to/status فارغين → نجيب كل شيء، ونفلتر في الواجهة
      );

      final parsed = list.map<_BookingVM>((raw) {
        final m = Map<String, dynamic>.from(raw as Map);

        final expert =
            (m['expert'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final service =
            (m['service'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final meeting =
            (m['meeting'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
        final review =
            (m['review'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

        final startAtStr = (m['startAt'] ?? '').toString();
        final endAtStr = (m['endAt'] ?? '').toString();
        DateTime? startAt;
        DateTime? endAt;
        if (startAtStr.isNotEmpty) {
          startAt = DateTime.tryParse(startAtStr)?.toLocal();
        }
        if (endAtStr.isNotEmpty) {
          endAt = DateTime.tryParse(endAtStr)?.toLocal();
        }

        final expertName =
            (expert['name'] ?? 'Expert').toString();
        final expertAvatarRaw =
            (expert['profileImageUrl'] ?? '').toString();
        final expertAvatar = ApiConfig.fixAssetUrl(expertAvatarRaw);

        final serviceTitle = (service['title'] ?? '').toString();
        final price = (service['price'] ?? m['payment']?['amount'] ?? 0).toDouble();
        final currency =
            (service['currency'] ?? m['payment']?['currency'] ?? 'USD').toString();

        final status = (m['status'] ?? 'PENDING').toString();
        final code = (m['code'] ?? '').toString();

        final timezone = (m['timezone'] ?? 'Asia/Hebron').toString();
        final customerNote = (m['customerNote'] ?? '').toString();

        final meetingUrl = (meeting['joinUrl'] ?? '').toString();

        final rating = review['rating'] is num ? (review['rating'] as num).toDouble() : null;
        final comment = (review['comment'] ?? '').toString();

        return _BookingVM(
          id: m['id']?.toString() ?? m['_id']?.toString() ?? '',
          code: code,
          status: status,
          expertName: expertName,
          expertAvatarUrl: expertAvatar,
          serviceTitle: serviceTitle,
          price: price,
          currency: currency,
          startAt: startAt,
          endAt: endAt,
          timezone: timezone,
          customerNote: customerNote,
          meetingUrl: meetingUrl,
          rating: rating,
          reviewComment: comment.isEmpty ? null : comment,
        );
      }).toList()
        ..sort((a, b) {
          final da = a.startAt;
          final db = b.startAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return da.compareTo(db); // الأقدم أولاً
        });

      setState(() {
        _allBookings
          ..clear()
          ..addAll(parsed);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<_BookingVM> get _filteredBookings {
    final now = DateTime.now();
    return _allBookings.where((b) {
      switch (_filter) {
        case 'UPCOMING':
          if (b.startAt == null) return false;
          return b.startAt!.isAfter(now);
        case 'PAST':
          if (b.startAt == null) return false;
          return b.startAt!.isBefore(now);
        case 'PENDING':
          return b.status == 'PENDING';
        case 'COMPLETED':
          return b.status == 'COMPLETED';
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _onCancelBooking(_BookingVM booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Cancel booking"),
          content: Text(
            "Are you sure you want to cancel this booking?\n\nCode: ${booking.code}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text("Yes, cancel"),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ApiService.cancelCustomerBooking(booking.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking canceled successfully.")),
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to cancel booking: $e")),
      );
    }
  }

  Future<void> _onLeaveReview(_BookingVM booking) async {
    double rating = booking.rating ?? 5;
    final commentCtrl =
        TextEditingController(text: booking.reviewComment ?? '');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                "Rate your session with ${booking.expertName}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (i) {
                  final value = i + 1.0;
                  final isActive = rating >= value;
                  return IconButton(
                    onPressed: () {
                      rating = value;
                      // rebuild بس مو عندنا setState هنا → نستخدم StatefulBuilder لو حابة، لكن لتبسيط الموضوع:
                      (context as Element).markNeedsBuild();
                    },
                    icon: Icon(
                      Icons.star,
                      color: isActive ? Colors.amber : Colors.grey.shade400,
                      size: 28,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Write a short comment (optional)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                  ),
                  child: const Text("Submit review"),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != true) return;

    try {
      await ApiService.submitBookingReview(
        bookingId: booking.id,
        rating: rating.toInt(),
        comment: commentCtrl.text.trim().isEmpty
            ? null
            : commentCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review submitted successfully.")),
      );
      await _loadBookings();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit review: $e")),
      );
    }
  }

  Future<void> _onJoinSession(_BookingVM booking) async {
    if (booking.meetingUrl == null || booking.meetingUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No meeting link attached yet.")),
      );
      return;
    }

    final uri = Uri.tryParse(booking.meetingUrl!);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid meeting URL.")),
      );
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Bookings",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 900;

          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final bookings = _filteredBookings;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE7F5F8), Color(0xFFF7FBFD)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1150),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 24 : 12,
                    vertical: 16,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(isWide),
                      const SizedBox(height: 12),
                      _buildFiltersRow(isWide),
                      const SizedBox(height: 12),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _loadBookings,
                          child: bookings.isEmpty
                              ? ListView(
                                  children: const [
                                    SizedBox(height: 120),
                                    Center(
                                      child: Text(
                                        "No bookings yet.\nBook a session with an expert to see it here.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.only(
                                      bottom: 16, top: 4),
                                  itemCount: bookings.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final b = bookings[index];
                                    return _BookingCard(
                                      booking: b,
                                      onCancel: b.status == 'PENDING'
                                          ? () => _onCancelBooking(b)
                                          : null,
                                      onLeaveReview:
                                          b.status == 'COMPLETED'
                                              ? () => _onLeaveReview(b)
                                              : null,
                                      onJoinSession:
                                          (b.status == 'CONFIRMED' ||
                                                  b.status == 'IN_PROGRESS')
                                              ? () => _onJoinSession(b)
                                              : null,
                                    );
                                  },
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
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    final today = DateTime.now();
    final todayLabel =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final total = _allBookings.length;
    final upcomingCount = _allBookings
        .where((b) => b.startAt != null && b.startAt!.isAfter(DateTime.now()))
        .length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 24 : 18,
        vertical: isWide ? 18 : 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandDark, _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.event_available,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Your sessions overview",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Total bookings: $total • Upcoming: $upcomingCount • Today $todayLabel",
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
    );
  }

  Widget _buildFiltersRow(bool isWide) {
    final filters = [
      'ALL',
      'UPCOMING',
      'PAST',
      'PENDING',
      'COMPLETED',
    ];

    String label(String k) {
      switch (k) {
        case 'UPCOMING':
          return 'Upcoming';
        case 'PAST':
          return 'Past';
        case 'PENDING':
          return 'Pending';
        case 'COMPLETED':
          return 'Completed';
        default:
          return 'All';
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final bool active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(label(f)),
              selected: active,
              onSelected: (_) {
                setState(() {
                  _filter = f;
                });
              },
              selectedColor: _brand.withOpacity(0.15),
              labelStyle: TextStyle(
                color: active ? _brandDark : Colors.grey.shade700,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/* ============================
   View Model بسيط للـ Booking
   ============================ */
class _BookingVM {
  final String id;
  final String code;
  final String status;
  final String expertName;
  final String expertAvatarUrl;
  final String serviceTitle;
  final double price;
  final String currency;
  final DateTime? startAt;
  final DateTime? endAt;
  final String timezone;
  final String customerNote;
  final String? meetingUrl;
  final double? rating;
  final String? reviewComment;

  _BookingVM({
    required this.id,
    required this.code,
    required this.status,
    required this.expertName,
    required this.expertAvatarUrl,
    required this.serviceTitle,
    required this.price,
    required this.currency,
    required this.startAt,
    required this.endAt,
    required this.timezone,
    required this.customerNote,
    required this.meetingUrl,
    required this.rating,
    required this.reviewComment,
  });
}

/* ============================
   Card Widget لكل Booking
   ============================ */

class _BookingCard extends StatelessWidget {
  final _BookingVM booking;
  final VoidCallback? onCancel;
  final VoidCallback? onLeaveReview;
  final VoidCallback? onJoinSession;

  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);

  const _BookingCard({
    required this.booking,
    this.onCancel,
    this.onLeaveReview,
    this.onJoinSession,
  });

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return "—";
    final d =
        "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
    final t =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    return "$d • $t";
  }

  Color _statusColor(String status) {
    switch (status) {
      case "PENDING":
        return Colors.orange.shade500;
      case "CONFIRMED":
        return Colors.green.shade600;
      case "IN_PROGRESS":
        return Colors.blue.shade600;
      case "COMPLETED":
        return Colors.teal.shade700;
      case "CANCELED":
        return Colors.red.shade500;
      case "NO_SHOW":
        return Colors.red.shade800;
      case "REFUND_REQUESTED":
        return Colors.deepOrange.shade600;
      case "REFUNDED":
        return Colors.indigo.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case "PENDING":
        return "Pending confirmation";
      case "CONFIRMED":
        return "Confirmed";
      case "IN_PROGRESS":
        return "In progress";
      case "COMPLETED":
        return "Completed";
      case "CANCELED":
        return "Canceled";
      case "NO_SHOW":
        return "No show";
      case "REFUND_REQUESTED":
        return "Refund requested";
      case "REFUNDED":
        return "Refunded";
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 600;

        final avatar = CircleAvatar(
          radius: 24,
          backgroundColor: _brand.withOpacity(0.15),
          backgroundImage: booking.expertAvatarUrl.isNotEmpty
              ? NetworkImage(booking.expertAvatarUrl)
              : null,
          child: booking.expertAvatarUrl.isEmpty
              ? Text(
                  booking.expertName.isNotEmpty
                      ? booking.expertName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: _brandDark,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        );

        final statusColor = _statusColor(booking.status);

        final statusChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _statusLabel(booking.status),
            style: TextStyle(
              color: statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

        final mainInfo = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              booking.serviceTitle.isNotEmpty
                  ? booking.serviceTitle
                  : "Session with ${booking.expertName}",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Expert: ${booking.expertName}",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateTime(booking.startAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  "${booking.price.toStringAsFixed(2)} ${booking.currency}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _brandDark,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  "Code: ${booking.code}",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            if (booking.customerNote.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Note: ${booking.customerNote}",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (booking.rating != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    booking.rating!.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (booking.reviewComment != null &&
                      booking.reviewComment!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        booking.reviewComment!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.end,
          children: [
            if (onJoinSession != null)
              OutlinedButton.icon(
                onPressed: onJoinSession,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _brand.withOpacity(0.7)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.video_call, size: 16),
                label: const Text(
                  "Join session",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (onLeaveReview != null)
              OutlinedButton.icon(
                onPressed: onLeaveReview,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.amber.shade600),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                icon: const Icon(Icons.star, size: 16),
                label: const Text(
                  "Review",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (onCancel != null)
              FilledButton.icon(
                onPressed: onCancel,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text(
                  "Cancel",
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFE3EBF3)),
          ),
          padding: const EdgeInsets.all(14),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(child: mainInfo),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        statusChip,
                        const Spacer(),
                        if (actions.children.isNotEmpty) actions,
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    avatar,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          mainInfo,
                          const SizedBox(height: 8),
                          statusChip,
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (actions.children.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          actions,
                        ],
                      ),
                  ],
                ),
        );
      },
    );
  }
}
