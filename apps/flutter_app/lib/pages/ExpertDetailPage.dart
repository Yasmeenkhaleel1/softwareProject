// lib/pages/ExpertDetailPage.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/api/api_service.dart';
import 'dart:js' as js;
import 'dart:js_util' as js_util; 
/*───────────────────────────────────────────────────────────────
  CARD VALIDATION HELPERS
───────────────────────────────────────────────────────────────*/
String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

bool luhnCheck(String cardNumber) {
  final s = _digitsOnly(cardNumber);
  if (s.isEmpty) return false;

  int sum = 0;
  bool alternate = false;
  for (int i = s.length - 1; i >= 0; i--) {
    int n = int.parse(s[i]);
    if (alternate) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
    alternate = !alternate;
  }
  return (sum % 10 == 0);
}

String? validateCardNumber(String? v) {
  if (v == null || v.trim().isEmpty) return "Required";
  final s = _digitsOnly(v);
  if (s.length < 13 || s.length > 19) return "Card must be 13–19 digits";
  if (!luhnCheck(s)) return "Invalid card";
  return null;
}

String? validateExpiry(String? v) {
  if (v == null || v.trim().isEmpty) return "Required";
  final parts = v.split('/');
  if (parts.length != 2) return "MM/YY";
  final mm = int.tryParse(parts[0]) ?? -1;
  final yy = int.tryParse(parts[1]) ?? -1;
  if (mm < 1 || mm > 12) return "Invalid month";
  final now = DateTime.now();
  final thisYY = int.parse(now.year.toString().substring(2));
  final thisMM = now.month;
  if (yy < thisYY || (yy == thisYY && mm < thisMM)) return "Expired";
  return null;
}

String? validateCvv(String? v) {
  final s = _digitsOnly(v ?? '');
  if (s.length < 3 || s.length > 4) return "CVV 3–4 digits";
  return null;
}

/*───────────────────────────────────────────────────────────────
  EXPERT DETAIL PAGE
───────────────────────────────────────────────────────────────*/
class ExpertDetailPage extends StatefulWidget {
  final Map<String, dynamic> expert;
  const ExpertDetailPage({super.key, required this.expert});

  @override
  State<ExpertDetailPage> createState() => _ExpertDetailPageState();
}

class _ExpertDetailPageState extends State<ExpertDetailPage> {
  late final String baseUrl;
  Map<String, dynamic>? profile;
  List<dynamic> services = [];
  bool loading = true;

 String _resolveBaseUrl() {
  return "http://localhost:5000";
}


  // ✅ إصلاح روابط الصور للويب
  String _fixImageUrl(String url) {
    if (url.isEmpty) return url;
    if (kIsWeb && url.contains("localhost")) {
      return url.replaceAll("localhost", "127.0.0.1");
    }
    return url;
  }

  Future<String> _token() async {
    final t = await ApiService.getToken();
    return t ?? '';
  }

  Future<String?> _customerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  String? _extractId(dynamic v) {
    if (v == null) return null;
    if (v is Map) {
      final inner = v["_id"] ?? v["id"];
      return inner?.toString();
    }
    return v.toString();
  }

  String? _expertIdFromAny(Map<String, dynamic> obj) {
    final v = obj["_id"] ?? obj["id"];
    return v?.toString();
  }

  /// ✅ هنا أهم تعديل:
  /// لحجز المواعيد لازم نستخدم ExpertProfile._id (نفس اللي في Postman)
  /// عشان /calendar-status و /services يشتغلوا صح.
  String? _bookingExpertId() {
    // نأخذ الـ _id من الـ profile إن وجد، وإلا من widget.expert
    return _expertIdFromAny(profile ?? widget.expert);
  }

  @override
  void initState() {
    super.initState();
    baseUrl = _resolveBaseUrl();
    _load();
  }

  // ✅ استخدمنا public endpoints + تصحيح الحقول
  Future<void> _load() async {
    setState(() => loading = true);
    final expertId = _expertIdFromAny(widget.expert);
    if (expertId == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Missing expert id")));
      return;
    }

    try {
      final t = await _token();
      final headers = {if (t.isNotEmpty) 'Authorization': 'Bearer $t'};

      final p = await http.get(
        Uri.parse("$baseUrl/api/public/experts/$expertId"),
        headers: headers,
      );

      final s = await http.get(
        Uri.parse("$baseUrl/api/public/experts/$expertId/services"),
        headers: headers,
      );

      if (p.statusCode == 200) {
        profile = jsonDecode(p.body)["expert"] ?? widget.expert;
      } else {
        profile = widget.expert;
      }

      if (s.statusCode == 200) {
        final data = jsonDecode(s.body);
        services = (data["items"] ?? []) as List<dynamic>;
      } else {
        services = [];
      }
    } catch (e) {
      debugPrint("❌ load error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (widget.expert["name"] ?? "Expert").toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(fallbackName),
        backgroundColor: const Color(0xFF62C6D9),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _header(),
                  const SizedBox(height: 20),
                  _services(),
                ],
              ),
            ),
    );
  }

  Widget _header() {
    final name =
        (profile?["name"] ?? widget.expert["name"] ?? "Expert").toString();
    final specialty =
        (profile?["specialization"] ?? widget.expert["specialty"] ?? "—")
            .toString();
    final bg =
        (profile?["profileImageUrl"] ?? widget.expert["profileImageUrl"] ?? "")
            .toString();

    final fixedBg = _fixImageUrl(bg);

    return Stack(
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.teal.shade200,
            image: fixedBg.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(fixedBg),
                    fit: BoxFit.cover,
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: fixedBg.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(color: Colors.black26.withOpacity(0.2)),
                  ),
                )
              : null,
        ),
        Positioned(
          left: 12,
          bottom: 12,
          child: Row(children: [
            const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFF62C6D9),
                child: Icon(Icons.person, color: Colors.white)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(specialty,
                  style: const TextStyle(color: Colors.white70)),
            ])
          ]),
        )
      ],
    );
  }

  Widget _services() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8.0),
          child: Text(
            "Services",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        if (services.isEmpty)
          const Text("No published services yet.",
              style: TextStyle(color: Colors.grey)),
        ...services.map((s) => _serviceCard(s as Map<String, dynamic>)).toList(),
      ],
    );
  }

  Widget _serviceCard(Map<String, dynamic> s) {
    final title = (s["title"] ?? "Untitled").toString();
    final category = (s["category"] ?? "General").toString();
    final price = int.tryParse("${s["price"] ?? 0}") ?? 0;
    final currency = (s["currency"] ?? "USD").toString();
    final duration = int.tryParse("${s["durationMinutes"] ?? 60}") ?? 60;

    // ✅ استخرج أول صورة
    String cover = "";
    if (s["images"] != null && s["images"] is List && s["images"].isNotEmpty) {
      cover = s["images"][0].toString();
    }

    // ✅ استخدمنا دالة تصحيح الرابط للويب
    final imgUrl = _fixImageUrl(cover);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0.6,
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: () {
            final cleanUrl = imgUrl.trim();
            final isValidUrl =
                cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://');

            if (isValidUrl) {
              return Image.network(
                cleanUrl,
                width: 65,
                height: 65,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 65,
                  height: 65,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              );
            } else {
              return Container(
                width: 65,
                height: 65,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              );
            }
          }(),
        ),
        title: GestureDetector(
          onTap: () => _showServiceDetails(context, s),
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF285E6E),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category, style: const TextStyle(color: Colors.teal)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.attach_money, size: 15, color: Colors.grey),
                Text("$price $currency",
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
                const SizedBox(width: 10),
                const Icon(Icons.timer, size: 15, color: Colors.grey),
                Text("$duration min",
                    style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ],
            ),
          ],
        ),
        trailing: TextButton(
          child: const Text("Book",
              style: TextStyle(
                  color: Color(0xFF62C6D9), fontWeight: FontWeight.w600)),
          onPressed: () {
            final expertId = _bookingExpertId();
            final serviceId = (s["_id"] ?? s["id"])?.toString();
            if (expertId == null || serviceId == null) return;

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              builder: (_) => _SlotPickerSheet(
                expertId: expertId,
                durationMinutes: duration,
                service: s,
                baseUrl: baseUrl,
                price: price,
                currency: currency,
                getCustomerId: _customerId,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showServiceDetails(BuildContext context, Map<String, dynamic> service) {
    final title = (service["title"] ?? "Untitled").toString();
    final category = (service["category"] ?? "General").toString();
    final price = int.tryParse("${service["price"] ?? 0}") ?? 0;
    final currency = (service["currency"] ?? "USD").toString();
    final duration = int.tryParse("${service["durationMinutes"] ?? 60}") ?? 60;
    final desc =
        (service["description"] ?? "No description provided.").toString();

    String imageUrl = "";
    if (service["images"] != null &&
        service["images"] is List &&
        service["images"].isNotEmpty) {
      imageUrl = _fixImageUrl(service["images"][0].toString().trim());
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image,
                            size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Color(0xFF285E6E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(category,
                    style:
                        const TextStyle(color: Colors.teal, fontSize: 15)),
                const Divider(height: 20),
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 18, color: Colors.grey),
                    Text("$price $currency",
                        style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: 15),
                    const Icon(Icons.timer, size: 18, color: Colors.grey),
                    Text("$duration min",
                        style: const TextStyle(fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  "Description",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF62C6D9),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    label: const Text(
                      "Close",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
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
}

/*───────────────────────────────────────────────────────────────
  SLOT PICKER SHEET  (Calendly-like UI)
───────────────────────────────────────────────────────────────*/
class _SlotPickerSheet extends StatefulWidget {
  final String expertId;
  final int durationMinutes;
  final Map<String, dynamic> service;
  final String baseUrl;
  final int price;
  final String currency;
  final Future<String?> Function() getCustomerId;

  const _SlotPickerSheet({
    required this.expertId,
    required this.durationMinutes,
    required this.service,
    required this.baseUrl,
    required this.price,
    required this.currency,
    required this.getCustomerId,
  });

  @override
  State<_SlotPickerSheet> createState() => _SlotPickerSheetState();
}

class _SlotPickerSheetState extends State<_SlotPickerSheet> {
  bool loading = true;
  List<dynamic> days = [];
  String? error;

  String? _selectedDate; // "YYYY-MM-DD"
  List<dynamic> _selectedSlots = [];

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final token = await ApiService.getToken();

      // ✅ نطاق الأيام: من اليوم + 14 يوم (مثل مواقع الحجز العالمية)
      final now = DateTime.now();
      final fromDate = DateTime(now.year, now.month, now.day);
      final toDate = fromDate.add(const Duration(days: 14));

      String _fmt(DateTime d) =>
          "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

      final fromStr = _fmt(fromDate);
      final toStr = _fmt(toDate);

      final uri = Uri.parse(
          "${widget.baseUrl}/api/public/experts/${widget.expertId}/calendar-status?from=$fromStr&to=$toStr&durationMinutes=${widget.durationMinutes}");

      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        days = data['days'] ?? [];

        // ✅ اختر أول يوم فيه Slots متاحة
        if (days.isNotEmpty) {
          final firstWithSlots = days.firstWhere(
            (d) => (d['slots'] ?? []).isNotEmpty,
            orElse: () => days.first,
          );
          _selectedDate = firstWithSlots['date'];
          _selectedSlots = (firstWithSlots['slots'] ?? []) as List<dynamic>;
        }
      } else {
        error = "Failed to load slots (HTTP ${res.statusCode})";
      }
    } catch (e) {
      error = e.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _onDayTap(Map<String, dynamic> day) {
    setState(() {
      _selectedDate = day['date'];
      _selectedSlots = (day['slots'] ?? []) as List<dynamic>;
    });
  }

  // ✅ NEW: فتح لوحة الدفع في يسار الشاشة
void _bookSlot(BuildContext context, Map<String, dynamic> slot) async {
  final customerId = await widget.getCustomerId();
  if (customerId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please login to book a session.")),
    );
    return;
  }

  final serviceId = (widget.service["_id"] ?? widget.service["id"])?.toString();
  if (serviceId == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Service id missing.")),
    );
    return;
  }

  _showPaymentSheet(
    context: context,
    slot: slot,
    customerId: customerId,
    serviceId: serviceId,
  );
}



  void _showPaymentSheet({
    required BuildContext context,
    required Map<String, dynamic> slot,
    required String customerId,
    required String serviceId,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Payment",
      pageBuilder: (_, __, ___) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420, // 🌍 مناسب للويب واللابتوب
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 16,
                      offset: Offset(4, 0),
                      color: Colors.black26,
                    )
                  ],
                ),
                child: _PaymentSideSheet(
                  baseUrl: widget.baseUrl,
                  expertId: widget.expertId,
                  service: widget.service,
                  serviceId: serviceId,
                  price: widget.price,
                  currency: widget.currency,
                  slot: slot,
                  getCustomerId: widget.getCustomerId,
                ),
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, anim, __, child) {
        final offset = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut));
        return SlideTransition(position: offset, child: child);
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case "AVAILABLE":
        return Colors.teal;
      case "FULL":
        return Colors.redAccent;
      case "OFF":
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
          height: 320, child: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return SizedBox(
        height: 320,
        child: Center(child: Text(error!)),
      );
    }
    if (days.isEmpty) {
      return const SizedBox(
        height: 320,
        child: Center(child: Text("No available slots")),
      );
    }

    final serviceTitle = (widget.service["title"] ?? "Service").toString();

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Select time for",
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            Text(
              serviceTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF285E6E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${widget.price} ${widget.currency} • ${widget.durationMinutes} min",
              style: TextStyle(
                  color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),

            // 🔹 Legend (الألوان)
            Row(
              children: [
                _legendDot(Colors.teal, "Available"),
                const SizedBox(width: 12),
                _legendDot(Colors.redAccent, "Full"),
                const SizedBox(width: 12),
                _legendDot(Colors.grey, "Off"),
              ],
            ),
            const SizedBox(height: 12),

            // 🔹 Days horizontal list
            SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: days.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final d = days[index];
                  final dateStr = d['date'] as String;
                  final status = (d['status'] ?? "OFF") as String;
                  final slotsList = (d['slots'] ?? []) as List<dynamic>;
                  final hasSlots = slotsList.isNotEmpty;

                  final dt = DateTime.tryParse(dateStr);
                  final dayNum = dt?.day.toString().padLeft(2, '0') ?? "--";
                  final weekday = dt != null
                      ? ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                          [dt.weekday % 7]
                      : "";

                  final isSelected = _selectedDate == dateStr;
                  final baseColor = _statusColor(status);
                  final bgColor = isSelected
                      ? baseColor.withOpacity(0.18)
                      : baseColor.withOpacity(0.07);

                  return GestureDetector(
                    onTap: hasSlots ? () => _onDayTap(d) : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: hasSlots ? bgColor : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? baseColor
                              : hasSlots
                                  ? baseColor.withOpacity(0.4)
                                  : Colors.grey.shade400,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekday,
                            style: TextStyle(
                              fontSize: 11,
                              color: hasSlots ? baseColor : Colors.grey,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayNum,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: hasSlots ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: 4,
                            width: 26,
                            decoration: BoxDecoration(
                              color:
                                  hasSlots ? baseColor : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Slots grid
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _selectedSlots.isEmpty
                    ? const Center(
                        key: ValueKey("no-slots"),
                        child: Text("No available slots for this day."),
                      )
                    : GridView.builder(
                        key: const ValueKey("slots-grid"),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: kIsWeb ? 4 : 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: _selectedSlots.length,
                        itemBuilder: (context, index) {
                          final slot =
                              _selectedSlots[index] as Map<String, dynamic>;
                          final available = slot['available'] == true;
                          final start = DateTime.parse(slot['startAt']);

                          final label =
                              "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";

                          return AnimatedScale(
                            duration: const Duration(milliseconds: 120),
                            scale: available ? 1.0 : 0.97,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: available
                                    ? Colors.white
                                    : Colors.grey.shade200,
                                elevation: available ? 1.5 : 0,
                                foregroundColor: available
                                    ? const Color(0xFF62C6D9)
                                    : Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: available
                                        ? const Color(0xFF62C6D9)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              onPressed: available
                                  ? () => _bookSlot(context, slot)
                                  : null,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: available
                                      ? const Color(0xFF62C6D9)
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

/*───────────────────────────────────────────────────────────────
  PAYMENT SIDE SHEET (LEFT PANEL)
───────────────────────────────────────────────────────────────*/
class _PaymentSideSheet extends StatefulWidget {
  final String baseUrl;
  final String expertId;
  final String serviceId;
  final Map<String, dynamic> service;
  final int price;
  final String currency;
  final Map<String, dynamic> slot;
  final Future<String?> Function() getCustomerId;

  const _PaymentSideSheet({
    required this.baseUrl,
    required this.expertId,
    required this.serviceId,
    required this.service,
    required this.price,
    required this.currency,
    required this.slot,
    required this.getCustomerId,
  });

  @override
  State<_PaymentSideSheet> createState() => _PaymentSideSheetState();
}

class _PaymentSideSheetState extends State<_PaymentSideSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumber = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _holderName = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _cardNumber.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _holderName.dispose();
    super.dispose();
  }

   Future<void> _submit() async {
    // 🔐 الدفع عبر Stripe شغال للويب فقط حالياً
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Stripe payment is only available on web for now."),
        ),
      );
      return;
    }

    final customerId = await widget.getCustomerId();

    if (customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to complete payment.")),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // ------------------------------------------------------
      // 1) إنشاء الحجز بحالة PENDING
      // ------------------------------------------------------
      final startStr = widget.slot['startAt'] as String;
      final endStr   = widget.slot['endAt']   as String;

      final bookingRes = await ApiService.createPublicBooking(
        expertId: widget.expertId,
        serviceId: widget.serviceId,
        customerId: customerId,
        startAtIso: DateTime.parse(startStr).toUtc().toIso8601String(),
        endAtIso:   DateTime.parse(endStr).toUtc().toIso8601String(),
        timezone: "Asia/Hebron",
        note: "",
      );

      final booking   = bookingRes["booking"];
      final bookingId = booking["_id"];

      // ------------------------------------------------------
      // 2) إنشاء PaymentIntent في السيرفر
      // ------------------------------------------------------
      final intentRes = await ApiService.createStripeIntent(
        amount:        widget.price.toDouble(),
        currency:      widget.currency,
        customerId:    customerId,
        expertProfileId: widget.expertId,
        serviceId:     widget.serviceId,
        bookingId:     bookingId,
      );

      final clientSecret = intentRes["clientSecret"];
      final paymentId    = intentRes["paymentId"];

      if (clientSecret == null || paymentId == null) {
        throw Exception("Missing clientSecret or paymentId from backend.");
      }

      // ------------------------------------------------------
      // 3) فتح Stripe Elements (الكرت الحقيقي على الويب)
      //    openStripeCardForm ترجع Promise → لازم نستعمل promiseToFuture
      // ------------------------------------------------------
      final resultJson = await js_util.promiseToFuture<String>(
        js.context.callMethod(
          "openStripeCardForm",
          [clientSecret],
        ),
      );

      final result = jsonDecode(resultJson);

      if (result["error"] != null) {
        throw Exception(result["error"]);
      }

      final paymentIntentId = result["paymentIntentId"];
      final paymentMethodId = result["paymentMethodId"];

      // ------------------------------------------------------
      // 4) تأكيد الدفع في الباكند
      // ------------------------------------------------------
      await ApiService.confirmStripeIntent(
        paymentId:       paymentId,
        paymentIntentId: paymentIntentId,
        paymentMethodId: paymentMethodId,
      );

 // 5) SUCCESS — show dialog & close payment panel
if (!mounted) return;

// إغلاق Panel الدفع
Navigator.of(context).pop();

// عرض Dialog نجاح
await showDialog(
  context: context,
  builder: (_) => AlertDialog(
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
    title: const Text(
      "Booking Requested",
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    content: const Text(
      "Your booking has been created successfully.\n"
      "Please wait for the expert's approval.",
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text("OK"),
      ),
    ],
  ),
);


    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }



  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(widget.slot['startAt'] as String);
    final end = DateTime.parse(widget.slot['endAt'] as String);

    final dateLabel =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
    final timeLabel =
        "${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - "
        "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";

    final serviceTitle = (widget.service["title"] ?? "Service").toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.payment, color: Color(0xFF285E6E)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Confirm & Pay",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF285E6E),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5FBFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0F3F6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF285E6E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(dateLabel,
                              style: const TextStyle(color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(timeLabel,
                              style: const TextStyle(color: Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.attach_money,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Text(
                            "${widget.price} ${widget.currency}",
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 16),

const Text(
  "Secure payment",
  style: TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 16,
    color: Color(0xFF285E6E),
  ),
),

const Text(
  "You will enter your card details in a secure Stripe form.\n"
  "Your card data never touches our servers.",
  style: TextStyle(fontSize: 13, color: Colors.grey),
),

const SizedBox(height: 16),

ElevatedButton.icon(
  icon: const Icon(Icons.credit_card),
  label: const Text(
    "Pay with Stripe",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF62C6D9),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
    ),
  ),
  onPressed: _submitting ? null : _submit,
),

              ],
            ),
          ),
        ),

        
       
      ],
    );
  }
}
