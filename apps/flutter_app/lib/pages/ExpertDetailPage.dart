// lib/pages/ExpertDetailPage.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '/api/api_service.dart';


/*───────────────────────────────────────────────────────────────
  CARD VALIDATION HELPERS (Fixed)
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
    if (kIsWeb) return "http://localhost:5000";
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:5000";
    }
    return "http://localhost:5000";
  }

  Future<String> _token() async {
    final t = await ApiService.getToken();
    return t ?? '';
  }

  Future<String?> _customerId() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getString('userId');
    if (local != null && local.isNotEmpty) return local;

    final t = await ApiService.getToken() ?? '';
    if (t.isNotEmpty) {
      try {
        final res = await http.get(
          Uri.parse("$baseUrl/api/me"),
          headers: {'Authorization': 'Bearer $t'},
        );
        if (res.statusCode == 200) {
          final u = jsonDecode(res.body)['user'];
          final id = (u?['_id'] ?? u?['id'])?.toString();
          if (id != null) {
            await prefs.setString('userId', id);
            return id;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  /// helper: try to read _id / id from any value
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

  /// ✅ هذا هو ال id اللي بنستخدمه للـ availability (userId تبع الخبير)
  String? _bookingExpertId() {
    // جرّب مجموعة مفاتيح محتملة من أي ماب
    String? pickFrom(Map<String, dynamic>? m) {
      if (m == null) return null;
      for (final key in [
        "expertUser",   // غالباً هذا اللي عندك في ال profile
        "expertUserId",
        "userId",
        "user",
        "expert",
      ]) {
        final v = m[key];
        if (v != null) {
          final id = _extractId(v);
          if (id != null && id.isNotEmpty) return id;
        }
      }
      return null;
    }

    // 1) من ال profile اللي رجع من الباك
    String? v = pickFrom(profile);

    // 2) من الـ object اللي انبعت للصفحة
    v ??= pickFrom(widget.expert);

    // 3) آخر حل: استخدم _id تبع ال profile / widget.expert
    v ??= _expertIdFromAny(profile ?? widget.expert);

    debugPrint(
        "🟢 bookingExpertId resolved = $v   (profile keys=${profile?.keys.toList()}, widget.expert keys=${widget.expert.keys.toList()})");

    return v;
  }

  @override
  void initState() {
    super.initState();
    baseUrl = _resolveBaseUrl();
    _load();
  }

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
        Uri.parse("$baseUrl/api/experts/$expertId"),
        headers: headers,
      );
      final s = await http.get(
        Uri.parse("$baseUrl/api/experts/$expertId/services"),
        headers: headers,
      );

      if (p.statusCode == 200) {
        profile = jsonDecode(p.body)["expert"];
      } else {
        profile = widget.expert;
      }

      if (s.statusCode == 200) {
        services = (jsonDecode(s.body)["items"] ?? []) as List<dynamic>;
      } else {
        services = [];
      }
    } catch (e) {
      debugPrint("❌ load error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Load error: $e")));
      }
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
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
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
                  _about(),
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

    return Stack(children: [
      Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.teal.shade200,
          image: bg.isNotEmpty
              ? DecorationImage(image: NetworkImage(bg), fit: BoxFit.cover)
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
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
            Text(specialty, style: const TextStyle(color: Colors.white70)),
          ])
        ]),
      )
    ]);
  }

  Widget _about() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("About",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
        ],
      );

  Widget _services() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Services",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (services.isEmpty)
          const Text("No published services yet.",
              style: TextStyle(color: Colors.grey))
        else
          ...services
              .map((s) => _serviceCard(s as Map<String, dynamic>))
              .toList(),
      ],
    );
  }

  Widget _serviceCard(Map<String, dynamic> s) {
    final title = (s["title"] ?? "Untitled").toString();
    final category = (s["category"] ?? "-").toString();
    final price = int.tryParse("${s["price"] ?? 0}") ?? 0;
    final currency = (s["currency"] ?? "USD").toString();
    final duration = int.tryParse("${s["durationMinutes"] ?? 60}") ?? 60;
    final images = (s["images"] as List?)?.cast<String>() ?? [];
    final cover = images.isNotEmpty ? images.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            image: cover != null && cover.startsWith("http")
                ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                : null,
          ),
          child: (cover == null || !cover.startsWith("http"))
              ? const Icon(Icons.image, color: Colors.grey)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(category, style: const TextStyle(color: Colors.teal)),
              const SizedBox(height: 6),
              Wrap(spacing: 12, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.attach_money, size: 16),
                  Text("$price $currency")
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule, size: 16),
                  Text("$duration min")
                ]),
              ]),
            ],
          ),
        ),
        TextButton(
          onPressed: () async {
            final expertId = _bookingExpertId(); // ✅ id الصحيح للـ availability
            final serviceId = (s["_id"] ?? s["id"])?.toString();
            debugPrint("🟢 expertId used for booking: $expertId");
            if (expertId == null || serviceId == null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Missing ids")));
              return;
            }

            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16), bottom: Radius.circular(16)),
                    child: Material(
                      color: Colors.white,
                      child: _SlotPickerSheet(
                        expertId: expertId,
                        durationMinutes: duration,
                        service: s,
                        baseUrl: baseUrl,
                        price: price,
                        currency: currency,
                        getCustomerId: _customerId,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: const Text("Book"),
        )
      ]),
    );
  }
}

/*───────────────────────────────────────────────────────────────
  SLOT PICKER SHEET
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
  List<dynamic> slots = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<String> _token() async {
    final t = await ApiService.getToken();
    return t ?? '';
  }

  Future<void> _loadSlots() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = await _token();
      final now = DateTime.now().toUtc();
      final from = DateTime.utc(now.year, now.month, now.day);
      final to = from.add(const Duration(days: 14));
      final fromStr =
          "${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}";
      final toStr =
          "${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}";

      final uri = Uri.parse(
          "${widget.baseUrl}/api/experts/${widget.expertId}/availability/slots"
          "?from=$fromStr&to=$toStr&durationMinutes=${widget.durationMinutes}");

      debugPrint("🔵 Fetching slots from: $uri");
      final res = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      debugPrint("🔵 Response: ${res.statusCode}");
      debugPrint("🔵 Body: ${res.body}");
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        slots = (data['slots'] ?? []) as List<dynamic>;
        debugPrint("✅ Loaded slots: ${slots.length}");
      } else {
        error = "Failed (${res.statusCode})";
      }
    } catch (e) {
      error = "Error: $e";
    } finally {
      setState(() => loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(List<dynamic> slots) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final s in slots) {
      final d = DateTime.parse(s['startAt'].toString()).toLocal();
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      map.putIfAbsent(key, () => []);
      map[key]!.add({"startAt": s["startAt"], "endAt": s["endAt"]});
    }
    return map;
  }

  String _hm(DateTime d) =>
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
          height: 420, child: Center(child: CircularProgressIndicator()));
    }
    if (error != null) {
      return SizedBox(
        height: 420,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadSlots, child: const Text("Retry")),
          ],
        ),
      );
    }

    final grouped = _groupByDate(slots);
    if (grouped.isEmpty) {
      return const SizedBox(
          height: 280, child: Center(child: Text("No available slots")));
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 520),
      child: ListView(
        padding: const EdgeInsets.all(16),
        shrinkWrap: true,
        children: grouped.entries.map((e) {
          final date = e.key;
          final daySlots = e.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: daySlots.map((slot) {
                  final localStart = DateTime.parse(slot["startAt"]).toLocal();
                  final label = _hm(localStart);
                  return OutlinedButton(
                    onPressed: () async {
                      final customerId = await widget.getCustomerId();
                      if (customerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Login required")));
                        return;
                      }
                      await showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => PaymentDialog(
                          baseUrl: widget.baseUrl,
                          customerId: customerId,
                          expertId: widget.expertId,
                          serviceId:
                              (widget.service["_id"] ?? widget.service["id"])
                                  .toString(),
                          startAtUtc: slot["startAt"],
                          endAtUtc: slot["endAt"],
                          amount: widget.price,
                          currency: widget.currency,
                          prefillName: null,
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: Text(label),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }
}

/*───────────────────────────────────────────────────────────────
  PAYMENT DIALOG
───────────────────────────────────────────────────────────────*/
class PaymentDialog extends StatefulWidget {
  final String baseUrl;
  final String customerId;
  final String expertId;
  final String serviceId;
  final String startAtUtc;
  final String endAtUtc;
  final int amount;
  final String currency;
  final String? prefillName;

  const PaymentDialog({
    super.key,
    required this.baseUrl,
    required this.customerId,
    required this.expertId,
    required this.serviceId,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.amount,
    required this.currency,
    this.prefillName,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final cardCtrl = TextEditingController();
  final expiryCtrl = TextEditingController();
  final cvvCtrl = TextEditingController();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    nameCtrl.text = widget.prefillName ?? "";
  }

  Future<void> _submitPaymentAndBook({
    required String baseUrl,
    required String customerId,
    required String expertId,
    required String serviceId,
    required String startAtUtc,
    required String endAtUtc,
    required int amount,
    required String currency,
    required String cardholderName,
    required String cardNumber,
    required String expiryMMYY,
    required String cvv,
  }) async {
    final e1 = validateCardNumber(cardNumber);
    final e2 = validateExpiry(expiryMMYY);
    final e3 = validateCvv(cvv);
    if (e1 != null || e2 != null || e3 != null) {
      throw Exception(e1 ?? e2 ?? e3);
    }

    final parts = expiryMMYY.split('/');
    final expMonth = int.parse(parts[0]);
    final expYear = int.parse(parts[1]);
    final token = await ApiService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception("No token – please login again.");
    }
    final authHeaders = {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };

    final payRes = await http.post(
      Uri.parse("$baseUrl/api/payments/charge"),
      headers: authHeaders,
      body: jsonEncode({
        "amount": amount,
        "currency": currency,
        "cardholderName": cardholderName,
        "cardNumber": cardNumber,
        "expMonth": expMonth,
        "expYear": expYear,
        "cvv": cvv,
        "customer": customerId,
        "expert": expertId,
        "service": serviceId,
      }),
    );

    if (payRes.statusCode != 201) {
      final msg =
          (jsonDecode(payRes.body)["message"] ?? "Payment failed").toString();
      throw Exception(msg);
    }

    final paymentId = jsonDecode(payRes.body)["paymentId"];
    final bookRes = await http.post(
      Uri.parse("$baseUrl/api/bookings"),
      headers: authHeaders,
      body: jsonEncode({
        "expert": expertId,
        "service": serviceId,
        "startAt": startAtUtc,
        "endAt": endAtUtc,
        "timezone": "Asia/Hebron",
        "customerNote": "",
        "customer": customerId,
        "paymentId": paymentId,
      }),
    );

    if (bookRes.statusCode != 201) {
      final msg =
          (jsonDecode(bookRes.body)["message"] ?? "Booking failed").toString();
      throw Exception(msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Payment",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Total: ${widget.amount} ${widget.currency}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Cardholder Name",
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: cardCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Card Number",
                hintText: "4242 4242 4242 4242",
                border: OutlineInputBorder(),
              ),
              validator: validateCardNumber,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: expiryCtrl,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: "Expiry (MM/YY)",
                    hintText: "07/27",
                    border: OutlineInputBorder(),
                  ),
                  validator: validateExpiry,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: cvvCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "CVV",
                    hintText: "•••",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: validateCvv,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        try {
                          setState(() => busy = true);
                          await _submitPaymentAndBook(
                            baseUrl: widget.baseUrl,
                            customerId: widget.customerId,
                            expertId: widget.expertId,
                            serviceId: widget.serviceId,
                            startAtUtc: widget.startAtUtc,
                            endAtUtc: widget.endAtUtc,
                            amount: widget.amount,
                            currency: widget.currency,
                            cardholderName: nameCtrl.text.trim(),
                            cardNumber: cardCtrl.text.trim(),
                            expiryMMYY: expiryCtrl.text.trim(),
                            cvv: cvvCtrl.text.trim(),
                          );
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "✅ Payment captured and booking created",
                              ),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("❌ ${e.toString()}")),
                          );
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: const Text("Pay & Confirm"),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
