import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../../api/api_service.dart'; // ✅ احتفظي بـ ApiService
import '../../config/api_config.dart'; // ✅ للإصلاح فقط
import './chat/chat_page.dart';

class ExpertCustomersPage extends StatefulWidget {
  const ExpertCustomersPage({super.key});

  @override
  State<ExpertCustomersPage> createState() => _ExpertCustomersPageState();
}

class _ExpertCustomersPageState extends State<ExpertCustomersPage> {
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _brandDark = Color(0xFF285E6E);
  static const Color _bg = Color(0xFFF4F7FB);

  bool _loading = true;
  String? _error;

  // العملاء الذين حجزوا عند هذا الخبير
  final List<_CustomerContact> _customers = [];

  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final prefs = await SharedPreferences.getInstance();
    _myUserId = prefs.getString('userId'); // ID تبع الخبير (User)
    await _loadCustomersFromBookings();
  }

  Future<void> _loadCustomersFromBookings() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_myUserId == null) {
        setState(() {
          _error = "Please login to see your customers.";
          _loading = false;
        });
        return;
      }

      // ✅ استخدمي ApiService كما كانت
      final bookings = await ApiService.fetchExpertBookings();

      // نكوّن خريطة: customerId -> _CustomerContact
      final Map<String, _CustomerContact> map = {};

      for (final raw in bookings) {
        if (raw is! Map) continue;
        final b = Map<String, dynamic>.from(raw);

        // الكستمر جاينا من populate("customer", ...)
        final customer =
            (b['customer'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

        final customerId = customer['_id']?.toString();
        if (customerId == null || customerId.isEmpty) continue;

        final customerName = (customer['name'] ?? customer['email'] ?? 'Customer').toString();
        final customerEmail = (customer['email'] ?? '').toString();

        // ✅ فقط هنا أصلحي رابط الصورة
        String rawAvatar = (customer['profilePic'] ?? customer['profileImageUrl'] ?? '').toString();
        final avatarUrl = ApiConfig.fixAssetUrl(rawAvatar); // ✅ الإصلاح الوحيد

        final startAtStr = (b['startAt'] ?? '').toString();
        DateTime? startAt;
        if (startAtStr.isNotEmpty) {
          startAt = DateTime.tryParse(startAtStr);
        }

        final key = customerId;
        if (!map.containsKey(key)) {
          map[key] = _CustomerContact(
            id: customerId,
            name: customerName,
            email: customerEmail,
            avatarUrl: avatarUrl, // ✅ استخدام الرابط المصحح
            lastBookingAt: startAt,
            totalBookings: 1,
          );
        } else {
          final existing = map[key]!;
          existing.totalBookings += 1;
          if (startAt != null) {
            if (existing.lastBookingAt == null || existing.lastBookingAt!.isBefore(startAt)) {
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
        _customers
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

  Future<void> _openChatWithCustomer(_CustomerContact customer) async {
    try {
      // ✅ استخدمي ApiService كما كانت
      final conv = await ApiService.getOrCreateConversationAsExpert(
        customerId: customer.id,
      );

      final String convId = conv['_id'].toString();

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            conversationId: convId,
            otherUserName: customer.name,
            otherUserAvatar: customer.avatarUrl.isNotEmpty ? customer.avatarUrl : null,
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
          "My Customers",
          style: TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                                Icons.people_alt_outlined,
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
                                    "Build long-term relationships",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "You have worked with ${_customers.length} customer(s) • Today $todayLabel",
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

                    // ===== قائمة العملاء =====
                    Expanded(
                      child: _customers.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    "No customers yet.\nOnce you receive bookings, they will appear here.",
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
                              onRefresh: _loadCustomersFromBookings,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                                itemCount: _customers.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final customer = _customers[index];
                                  return _buildCustomerCard(customer);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildCustomerCard(_CustomerContact customer) {
    final lastStr = customer.lastBookingAt != null
        ? "${customer.lastBookingAt!.year}-${customer.lastBookingAt!.month.toString().padLeft(2, '0')}-${customer.lastBookingAt!.day.toString().padLeft(2, '0')}"
        : "—";

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 520; // ✅ موب/عرض ضيق
        final messageButton = FilledButton.icon(
          onPressed: () => _openChatWithCustomer(customer),
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
        );

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
            onTap: () => _openChatWithCustomer(customer),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: isCompact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: _brand.withOpacity(0.15),
                              backgroundImage: customer.avatarUrl.isNotEmpty ? NetworkImage(customer.avatarUrl) : null,
                              child: customer.avatarUrl.isEmpty
                                  ? Text(
                                      customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: _brandDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: _customerInfo(customer, lastStr, compact: true)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(width: double.infinity, child: messageButton), // ✅ الزر ينزل تحت ويأخذ العرض
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: _brand.withOpacity(0.15),
                          backgroundImage: customer.avatarUrl.isNotEmpty ? NetworkImage(customer.avatarUrl) : null,
                          child: customer.avatarUrl.isEmpty
                              ? Text(
                                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: _brandDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: _customerInfo(customer, lastStr, compact: false)),
                        const SizedBox(width: 10),
                        messageButton,
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _customerInfo(_CustomerContact customer, String lastStr, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          customer.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis, // ✅ منع overflow بالاسم
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        if (customer.email.isNotEmpty)
          Text(
            customer.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // ✅ منع overflow بالإيميل
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
        const SizedBox(height: 6),

        // ✅ بدل Row (اللي بيسبب overflow) نستخدم Wrap على الشاشات الضيقة
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.event_available, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  "Bookings: ${customer.totalBookings}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  "Last: $lastStr",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _CustomerContact {
  final String id; // User._id للكستمر
  final String name;
  final String email;
  final String avatarUrl;
  DateTime? lastBookingAt;
  int totalBookings;

  _CustomerContact({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    required this.lastBookingAt,
    required this.totalBookings,
  });
}
