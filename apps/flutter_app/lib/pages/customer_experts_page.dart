import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../api/api_service.dart';
import './chat/chat_page.dart';

class CustomerExpertsPage extends StatefulWidget {
  const CustomerExpertsPage({super.key});

  @override
  State<CustomerExpertsPage> createState() => _CustomerExpertsPageState();
}

class _CustomerExpertsPageState extends State<CustomerExpertsPage> {
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  bool _loading = true;
  String? _error;

  // experts اللي حجز معهم هذا الكستمر
  final List<_ExpertContact> _experts = [];

  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getString('userId');
    await _loadExpertsFromBookings();
  }

  Future<void> _loadExpertsFromBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_myUserId == null) {
        setState(() {
          _error = "Please login to see your experts.";
          _loading = false;
        });
        return;
      }

      // نجيب كل الحجوزات لهذا الكستمر
      final bookings = await ApiService.fetchCustomerBookings(
        customerId: _myUserId!,
        // بدون من/إلى → يجيب كل الحجوزات (الباك إند هو اللي يحدد)
      );

      // نكوّن خريطة: expertUserId -> _ExpertContact
      final Map<String, _ExpertContact> map = {};

      for (final raw in bookings) {
  if (raw is! Map) continue;
  final b = Map<String, dynamic>.from(raw);

  // 👈 نقرأ UserId الحقيقي للخبير من الـ booking
  final expertUserId = (b['expertUserId'] ?? '').toString();
  if (expertUserId.isEmpty) continue;

  // ExpertProfile (للعرض: الاسم، الصورة، ...الخ)
  final expert =
      (b['expert'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};

  final expertName =
      (expert['name'] ?? 'Expert').toString();
  final avatar = (expert['profileImageUrl'] ?? '').toString();
  final expertEmail = ''; // لو بدك تجيبي الإيميل لاحقاً من User

  final startAtStr = (b['startAt'] ?? '').toString();
  DateTime? startAt;
  if (startAtStr.isNotEmpty) {
    startAt = DateTime.tryParse(startAtStr);
  }

  final key = expertUserId; // 👈 المفتاح الآن هو User._id
  if (!map.containsKey(key)) {
    map[key] = _ExpertContact(
      id: expertUserId,        // 👈 هذا اللي يروح للـ API تبع الشات
      name: expertName,
      email: expertEmail,
      avatarUrl: avatar,
      lastBookingAt: startAt,
      totalBookings: 1,
    );
  } else {
    final existing = map[key]!;
    existing.totalBookings += 1;
    if (startAt != null) {
      if (existing.lastBookingAt == null ||
          existing.lastBookingAt!.isBefore(startAt)) {
        existing.lastBookingAt = startAt;
      }
    }
  }
}


      final list = map.values.toList()
        ..sort((a, b) {
          final da = a.lastBookingAt;
          final db = b.lastBookingAt;
          if (da == null && db == null) return 0;
          if (da == null) return 1;
          if (db == null) return -1;
          return db.compareTo(da); // الأحدث أولاً
        });

      setState(() {
        _experts
          ..clear()
          ..addAll(list);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openChatWithExpert(_ExpertContact expert) async {
    try {
      // نستخدم الـ API اللي جهزناه سابقاً
      final conv = await ApiService.getOrCreateConversationAsCustomer(
        expertId: expert.id,
      );

      final String convId = conv['_id'].toString();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: convId,
            otherUserName: expert.name,
            otherUserAvatar: expert.avatarUrl.isNotEmpty ? expert.avatarUrl : null,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open chat: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayLabel =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _brand,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Experts I worked with",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    // ===== الهيدر الجميل =====
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
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
                                Icons.forum,
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
                                    "Stay in touch with your experts",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "You have worked with ${_experts.length} expert(s) • Today $todayLabel",
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
                      ),
                    ),

                    const SizedBox(height: 4),

                    // ===== قائمة الإكسبرتس =====
                    Expanded(
                      child: _experts.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    "No experts yet.\nBook a session to start a conversation.",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            )
                          : RefreshIndicator(
                              onRefresh: _loadExpertsFromBookings,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 16),
                                itemCount: _experts.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final expert = _experts[index];
                                  return _buildExpertCard(expert);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildExpertCard(_ExpertContact expert) {
    final lastStr = expert.lastBookingAt != null
        ? "${expert.lastBookingAt!.year}-${expert.lastBookingAt!.month.toString().padLeft(2, '0')}-${expert.lastBookingAt!.day.toString().padLeft(2, '0')}"
        : "—";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openChatWithExpert(expert),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 26,
                backgroundColor: _brand.withOpacity(0.15),
                backgroundImage: expert.avatarUrl.isNotEmpty
                    ? NetworkImage(expert.avatarUrl)
                    : null,
                child: expert.avatarUrl.isEmpty
                    ? Text(
                        expert.name.isNotEmpty
                            ? expert.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: _brandDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),

              // نصوص + معلومات
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expert.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (expert.email.isNotEmpty)
                      Text(
                        expert.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.event_available,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "Bookings: ${expert.totalBookings}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          "Last: $lastStr",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // زر المسج
              FilledButton.icon(
                onPressed: () => _openChatWithExpert(expert),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.message, size: 18),
                label: const Text(
                  "Message",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpertContact {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  DateTime? lastBookingAt;
  int totalBookings;

  _ExpertContact({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.lastBookingAt,
    required this.totalBookings,
  });
}
