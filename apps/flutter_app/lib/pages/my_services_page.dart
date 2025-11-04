import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'service_form_page.dart';
import 'service_public_preview_page.dart';

class MyServicesPage extends StatefulWidget {
  const MyServicesPage({super.key});

  @override
  State<MyServicesPage> createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage>
    with SingleTickerProviderStateMixin {
 static const baseUrl = "http://localhost:5000";

void _showDialog(String title, String msg) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
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

  late TabController _tab;
  bool _loading = true;
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;

  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) _fetchAll();
    });
    _fetchAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

String _buildMeUrl() {
  // ✅ هذا هو المسار الصحيح
  final base = "$baseUrl/api/services/me";

  final qp = <String, String>{
    "page": "1",
    "limit": "50",
  };

  if (_query.trim().isNotEmpty) qp["q"] = _query.trim();

  switch (_tab.index) {
    case 1:
      qp["status"] = "ACTIVE";
      qp["published"] = "true";
      break;
    case 2:
      qp["status"] = "ACTIVE";
      qp["published"] = "false";
      break;
    case 3:
      qp["status"] = "ARCHIVED";
      break;
  }

  // ✅ هنا نضيف المعاملات للعنوان الصحيح
  final qs = qp.entries.map((e) => "${e.key}=${Uri.encodeComponent(e.value)}").join("&");
  return "$base?$qs"; // ✅ الآن الرابط صحيح 100%
}


  Future<void> _fetchAll() async {
    try {
      setState(() => _loading = true);
      final t = await _token();
      final headers = {'Authorization': 'Bearer $t'};

      final listUrl = _buildMeUrl();
      final res = await http.get(Uri.parse(listUrl), headers: headers);

      final st = await http.get(Uri.parse("$baseUrl/api/services/me/stats"), headers: headers);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _items = data['items'] ?? [];
          _stats = st.statusCode == 200 ? jsonDecode(st.body) : null;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("❌ Fetch error: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _togglePublish(String id, bool value) async {
    final t = await _token();
    final res = await http.patch(
      Uri.parse("$baseUrl/api/services/$id/publish"),
      headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
      body: jsonEncode({'isPublished': value}),
    );
    if (res.statusCode == 200) {
     _showDialog("Success", value ? "Service published" : "Service hidden");

      _fetchAll();
    } else {
      _showDialog("Error", res.body);

    }
  }

  Future<void> _archive(String id) async {
  final t = await _token();
  final res = await http.delete(
    Uri.parse("$baseUrl/api/services/$id"),
    headers: {'Authorization': 'Bearer $t'},
  );
  if (res.statusCode == 200) {
    _showDialog("Archived", "Service archived");

    _fetchAll();
  } else {
    _showDialog("Error", res.body);

  }
}

// ✅ دالة جديدة لفك الأرشفة (إرجاع الخدمة إلى Hidden)
Future<void> _unarchive(String id) async {
  final t = await _token();
  final res = await http.patch(
    Uri.parse("$baseUrl/api/services/$id/unarchive"),
    headers: {
      'Authorization': 'Bearer $t',
      'Content-Type': 'application/json'
    },
    body: jsonEncode({'status': 'ACTIVE', 'isPublished': false}),
  );

  if (res.statusCode == 200) {
   _showDialog("Restored", "Service unarchived");

    _fetchAll();
  } else {
   _showDialog("Error", res.body);

  }
}

  Future<void> _duplicate(String id) async {
    final t = await _token();
    final res = await http.post(
      Uri.parse("$baseUrl/api/services/$id/duplicate"),
      headers: {'Authorization': 'Bearer $t'},
    );
    if (res.statusCode == 201) {
     _showDialog("Duplicated", "Service duplicated");

      _fetchAll();
    } else {
     _showDialog("Error", res.body);

    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _query = v);
      _fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text("My Services", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Published"),
            Tab(text: "Hidden"),
            Tab(text: "Archived"),
          ],
        ),
        actions: [
          IconButton(onPressed: _fetchAll, icon: const Icon(Icons.refresh, color: Colors.white)),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF62C6D9),
        icon: const Icon(Icons.add),
        label: const Text("Add Service"),
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ServiceFormPage()),
          );
          if (created == true) _fetchAll();
        },
      ),

      body: Column(
        children: [
          // 🔍 البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: "Search by title or description...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_stats != null) _buildStatsRow(),

          const SizedBox(height: 8),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text("No services found.", style: TextStyle(color: Colors.grey)))
                    : RefreshIndicator(
                        onRefresh: _fetchAll,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _buildServiceCard(_items[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final s = _stats!;
    Widget chip(String label, String value, IconData icon) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF62C6D9)),
            const SizedBox(width: 8),
            Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: chip("Total", "${s['total']}", Icons.all_inbox)),
          const SizedBox(width: 8),
          Expanded(child: chip("Published", "${s['published']}", Icons.visibility)),
          const SizedBox(width: 8),
          Expanded(child: chip("Active", "${s['active']}", Icons.check_circle)),
          const SizedBox(width: 8),
          Expanded(child: chip("Archived", "${s['archived']}", Icons.archive)),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> sv) {
    final String title = sv['title'] ?? 'Untitled';
    final String category = sv['category'] ?? '-';
    final double price = (sv['price'] ?? 0).toDouble();
    final String currency = sv['currency'] ?? 'USD';
    final int duration = (sv['durationMinutes'] ?? 60) as int;

    final bool isPublished = sv['isPublished'] == true;
    final bool isArchived = (sv['status'] ?? 'ACTIVE') == 'ARCHIVED';

    final double rating = (sv['ratingAvg'] ?? 0).toDouble();
    final int ratingCount = (sv['ratingCount'] ?? 0) as int;
    final int bookings = (sv['bookingsCount'] ?? 0) as int;

    final List images = (sv['images'] ?? []) as List;
    final String? cover = images.isNotEmpty ? images.first.toString() : null;

    Color badgeColor;
    String badgeText;
    if (isArchived) {
      badgeColor = Colors.grey;
      badgeText = "Archived";
    } else if (isPublished) {
      badgeColor = Colors.green;
      badgeText = "Published";
    } else {
      badgeColor = Colors.orange;
      badgeText = "Hidden";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // صورة
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              image: (cover != null && cover.startsWith("http"))
                  ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                  : null,
            ),
            child: (cover == null || !cover.startsWith("http"))
                ? const Icon(Icons.image, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 14),

          // تفاصيل
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // عنوان + بادج
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(badgeText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(category, style: const TextStyle(color: Colors.teal)),
                const SizedBox(height: 8),

                // معلومات سريعة
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: [
                    _kv(Icons.attach_money, "${price.toStringAsFixed(2)} $currency"),
                    _kv(Icons.schedule, "$duration min"),
                    _kv(Icons.star, "${rating.toStringAsFixed(1)} ($ratingCount)"),
                    _kv(Icons.event_available, "$bookings bookings"),
                  ],
                ),

                const SizedBox(height: 12),

                // أزرار
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _btn(Icons.remove_red_eye, "Preview", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ServicePublicPreviewPage(service: sv)),
                      );
                    }),
                    _btn(Icons.copy, "Duplicate", () => _duplicate(sv['_id'])),
                    _btn(Icons.edit, "Edit", () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ServiceFormPage(existing: sv)),
                      );
                      if (updated == true) _fetchAll();
                    }),
                    _btn(isPublished ? Icons.visibility_off : Icons.visibility, isPublished ? "Hide" : "Publish",
                        () => _togglePublish(sv['_id'], !isPublished)),
                    _dangerBtn(
  isArchived ? Icons.unarchive : Icons.archive,
  isArchived ? "Unarchive" : "Archive",
  () => isArchived ? _unarchive(sv['_id']) : _archive(sv['_id']),
),

                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  Widget _btn(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: const Color(0xFF62C6D9)),
      label: Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
    );
  }

  Widget _dangerBtn(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: Colors.redAccent),
      label: Text(label, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
    );
  }
}
