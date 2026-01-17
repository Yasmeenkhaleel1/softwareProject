import 'package:flutter/material.dart';
import '../services/notifications_api.dart';
import 'booking_detail_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);
  static const Color _pageBg = Color(0xFFF5F7FB);

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  bool _showUnreadOnly = false;
  String _q = "";

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await NotificationsAPI.getAll();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    await NotificationsAPI.markAllAsRead();
    await _fetch();
  }

  Future<void> _openNotification(Map<String, dynamic> n) async {
    final id = (n['_id'] ?? '').toString();
    if (id.isNotEmpty) {
      await NotificationsAPI.markOneAsRead(id);
    }

    // ✅ navigation by link (backend sends link)
    final link = (n['link'] ?? '').toString().trim();
    final data = (n['data'] is Map) ? Map<String, dynamic>.from(n['data']) : <String, dynamic>{};

    if (!mounted) return;

    // إذا عندك routes جاهزة استخدمي Navigator.pushNamed
    // وإلا اعملي routing حسب صفحاتك
    _navigateByLinkOrData(link, data);

    // بعد الرجوع حدثّي
    _fetch();
  }

  void _navigateByLinkOrData(String link, Map<String, dynamic> data) {
    // ✅ أمثلة—عدّليها حسب صفحاتك الحقيقية
    // 1) Messages
    if (link.startsWith('/messages/')) {
      // لو عندك ConversationsPage فقط:
      Navigator.pop(context); // سكّري صفحة الإشعارات
      // وروّحي للمحادثات أو للشات حسب عندك
      // Navigator.push(context, MaterialPageRoute(builder: (_) => const ConversationsPage()));
      return;
    }

   // 2) Booking details (يدعم كل الصيغ)
  final bookingIdFromData = (data['bookingId'] ?? '').toString().trim();

  String bookingId = '';
  if (link.startsWith('/expert/bookings/')) {
    bookingId = link.split('/').last.trim();
  } else if (link.startsWith('/booking/')) {
    bookingId = link.split('/').last.trim();
  } else if (bookingIdFromData.isNotEmpty) {
    bookingId = bookingIdFromData; 
  }

  if (bookingId.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingDetailPage(bookingId: bookingId)),
    );
    return;
  }


    // 3) fallback
    // لو ما في link واضح
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opened notification (route not mapped yet).')),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> list = List.of(_items);

    if (_showUnreadOnly) {
      list = list.where((n) => n['readAt'] == null).toList();
    }

    if (_q.trim().isNotEmpty) {
      final q = _q.toLowerCase();
      list = list.where((n) {
        final t = (n['title'] ?? '').toString().toLowerCase();
        final b = (n['body'] ?? '').toString().toLowerCase();
        return t.contains(q) || b.contains(q);
      }).toList();
    }

    return list;
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  IconData _iconFor(Map<String, dynamic> n) {
    final data = (n['data'] is Map) ? Map<String, dynamic>.from(n['data']) : {};
    final type = (data['type'] ?? '').toString();
    if (type == 'NEW_MESSAGE') return Icons.chat_bubble_outline_rounded;
    if (type == 'NEW_BOOKING') return Icons.event_available_rounded;
    if (type == 'BOOKING_ACCEPTED') return Icons.verified_rounded;
    return Icons.notifications_active_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _brand,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
        ),
        actions: [
          TextButton.icon(
            onPressed: _loading ? null : _markAllRead,
            icon: const Icon(Icons.done_all_rounded, color: Colors.white),
            label: const Text('Mark all', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _headerCard(),
            const SizedBox(height: 12),

            if (_loading) _loadingCard(),
            if (!_loading && _error != null) _errorCard(_error!),
            if (!_loading && _error == null) ...[
              if (_filtered.isEmpty) _emptyCard(),
              ..._filtered.map(_notifTile),
              const SizedBox(height: 80),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(blurRadius: 18, offset: const Offset(0, 10), color: Colors.black.withOpacity(0.06))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: 'Search notifications...',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _brand.withOpacity(0.8))),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip('All', !_showUnreadOnly, () => setState(() => _showUnreadOnly = false)),
                const SizedBox(width: 8),
                _chip('Unread', _showUnreadOnly, () => setState(() => _showUnreadOnly = true)),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _fetch,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _brand.withOpacity(0.14) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? _brand.withOpacity(0.35) : _border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? _ink : _muted,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  Widget _notifTile(Map<String, dynamic> n) {
    final title = (n['title'] ?? '').toString();
    final body = (n['body'] ?? '').toString();
    final createdAt = (n['createdAt'] ?? '').toString();
    final unread = n['readAt'] == null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openNotification(n),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: unread ? _brand.withOpacity(0.35) : _border),
            boxShadow: [BoxShadow(blurRadius: 16, offset: const Offset(0, 10), color: Colors.black.withOpacity(0.06))],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _brand.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Icon(_iconFor(n), color: _brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.isEmpty ? 'Notification' : title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(createdAt),
                          style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body.isEmpty ? '—' : body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
                    ),
                    if (unread) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.red.withOpacity(0.25)),
                          ),
                          child: const Text(
                            'UNREAD',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 12),
          Text('Loading notifications...', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _errorCard(String e) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w900, color: _ink)),
          const SizedBox(height: 6),
          Text(e, style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _fetch,
            style: ElevatedButton.styleFrom(backgroundColor: _brand),
            child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
          )
        ],
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: const Row(
        children: [
          Icon(Icons.notifications_off_outlined),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'No notifications yet.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
