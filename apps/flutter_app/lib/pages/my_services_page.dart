import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter/foundation.dart';

import 'service_form_page.dart';
import 'service_public_preview_page.dart';

class MyServicesPage extends StatefulWidget {
  const MyServicesPage({super.key});

  @override
  State<MyServicesPage> createState() => _MyServicesPageState();
}

class _MyServicesPageState extends State<MyServicesPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";
    } else {
      return "http://10.0.2.2:5000";
    }
  }

  late TabController _tab;
  bool _loading = true;
  bool _isRefreshing = false;
  List<dynamic> _items = [];
  Map<String, dynamic>? _stats;

  String _query = '';
  Timer? _debounce;
  ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(_handleTabChange);
    _scrollController.addListener(_handleScroll);
    _fetchAll();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tab.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchAll(silent: true);
    }
  }

  void _handleTabChange() {
    if (!_tab.indexIsChanging) {
      _currentPage = 1;
      _hasMore = true;
      _fetchAll();
    }
  }

  void _handleScroll() {
    if (_scrollController.position.pixels ==
            _scrollController.position.maxScrollExtent &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    try {
      setState(() => _loading = true);
      final t = await _token();
      final headers = {'Authorization': 'Bearer $t'};

      final nextPage = _currentPage + 1;
      final url = "${_buildMeUrl().split('?').first}?page=$nextPage&limit=20";

      final res = await http.get(Uri.parse(url), headers: headers);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newItems = data['items'] ?? [];

        setState(() {
          _items.addAll(newItems);
          _currentPage = nextPage;
          _hasMore = newItems.isNotEmpty;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) {
      setState(() => _loading = true);
    }

    try {
      final t = await _token();
      final headers = {'Authorization': 'Bearer $t'};

      final listUrl = _buildMeUrl();
      final res = await http.get(Uri.parse(listUrl), headers: headers);
      final st = await http.get(
        Uri.parse("$baseUrl/api/services/me/stats"),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _items = data['items'] ?? [];
          _stats = st.statusCode == 200 ? jsonDecode(st.body) : null;
          _loading = false;
          _isRefreshing = false;
        });
      } else {
        setState(() {
          _loading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await _fetchAll(silent: true);
  }

  Future<void> _showDialog(String title, String msg,
      {bool isSuccess = true}) async {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: EdgeInsets.all(isLargeScreen ? 40 : 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 400 : double.infinity,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color:
                      isSuccess ? const Color(0xFF62C6D9) : Colors.redAccent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      msg,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF64748B),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSuccess
                                  ? const Color(0xFF62C6D9)
                                  : Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "OK",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeUrl() {
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

    final qs = qp.entries
        .map((e) => "${e.key}=${Uri.encodeComponent(e.value)}")
        .join("&");
    return "$base?$qs";
  }

  Future<void> _togglePublish(String id, bool value) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(value ? "Publish Service" : "Hide Service"),
        content: Text(value
            ? "Are you sure you want to publish this service? It will be visible to all users."
            : "Are you sure you want to hide this service? It will not be visible to users."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: value ? Colors.green : Colors.orange,
            ),
            child: Text(value ? "Publish" : "Hide"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final t = await _token();
      final res = await http.patch(
        Uri.parse("$baseUrl/api/services/$id/publish"),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'isPublished': value}),
      );

      Navigator.pop(context);

      if (res.statusCode == 200) {
        await _showDialog(
          "Success",
          value
              ? "Service published successfully"
              : "Service hidden successfully",
          isSuccess: true,
        );
        _fetchAll();
      } else {
        await _showDialog("Error", "Failed to update service",
            isSuccess: false);
      }
    } catch (e) {
      Navigator.pop(context);
      await _showDialog("Error", "Network error occurred", isSuccess: false);
    }
  }

  Future<void> _archive(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Archive Service"),
        content: const Text(
            "Are you sure you want to archive this service? You can restore it later."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: const Text("Archive"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final t = await _token();
    final res = await http.delete(
      Uri.parse("$baseUrl/api/services/$id"),
      headers: {'Authorization': 'Bearer $t'},
    );

    if (res.statusCode == 200) {
      await _showDialog("Archived", "Service archived successfully",
          isSuccess: true);
      _fetchAll();
    } else {
      await _showDialog("Error", "Failed to archive service", isSuccess: false);
    }
  }

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
      await _showDialog("Restored", "Service unarchived successfully",
          isSuccess: true);
      _fetchAll();
    } else {
      await _showDialog("Error", "Failed to unarchive service",
          isSuccess: false);
    }
  }

  Future<void> _duplicate(String id) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final t = await _token();
    final res = await http.post(
      Uri.parse("$baseUrl/api/services/$id/duplicate"),
      headers: {'Authorization': 'Bearer $t'},
    );

    Navigator.pop(context);

    if (res.statusCode == 201) {
      await _showDialog("Duplicated", "Service duplicated successfully",
          isSuccess: true);
      _fetchAll();
    } else {
      await _showDialog("Error", "Failed to duplicate service",
          isSuccess: false);
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
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: const Color(0xFF62C6D9),
              pinned: true,
              floating: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: const Text(
                  "",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
            ),
          ];
        },
        body: Column(
          children: [
            // عرض الإحصائيات هنا (تحت AppBar، فوق التاب بار)
            if (_stats != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _buildStatsRow(),
              ),
            
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: List.generate(4, (index) => _buildTabContent()),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(isPortrait, screenWidth),
    );
  }

  Widget _buildTabContent() {
    return Column(
      children: [
        // 🔍 شريط البحث
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF62C6D9)),
                hintText: "Search by title or description...",
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: _loading && _items.isEmpty
              ? _buildShimmerLoader()
              : _items.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _refreshData,
                      color: const Color(0xFF62C6D9),
                      child: AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _items.length) {
                              return _buildLoadMoreIndicator();
                            }
                            return AnimationConfiguration.staggeredList(
                              position: i,
                              duration: const Duration(milliseconds: 500),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 12),
                                    child: _buildServiceCard(_items[i]),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final s = _stats!;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    Widget statCard(String label, String value, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: isLargeScreen ? 18 : 16),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 11 : 9,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        statCard("Total", "${s['total']}", Icons.all_inbox,
            const Color(0xFF62C6D9)),
        statCard("Published", "${s['published']}", Icons.visibility,
            Colors.green),
        statCard("Active", "${s['active']}", Icons.check_circle, Colors.blue),
        statCard("Archived", "${s['archived']}", Icons.archive, Colors.grey),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 4,
      itemBuilder: (_, i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 16,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.only(bottom: 6),
                    ),
                    Container(
                      width: 80,
                      height: 12,
                      color: Colors.grey[200],
                      margin: const EdgeInsets.only(bottom: 8),
                    ),
                    Container(
                      width: double.infinity,
                      height: 12,
                      color: Colors.grey[200],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.work_outline,
                  size: 60,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "No Services Found",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "You haven't created any services yet. Start by adding your first service!",
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ServiceFormPage(existing: {}, service: {},)),
                  );
                  if (created == true) _fetchAll();
                },
                icon: const Icon(Icons.add),
                label: const Text("Create First Service"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62C6D9),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _hasMore
            ? const CircularProgressIndicator(color: Color(0xFF62C6D9))
            : const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  "No more services",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
      ),
    );
  }

  Widget _buildFloatingActionButton(bool isPortrait, double screenWidth) {
    return FloatingActionButton.extended(
      backgroundColor: const Color(0xFF62C6D9),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        isPortrait || screenWidth > 400 ? "Add Service" : "Add",
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      onPressed: () async {
        HapticFeedback.lightImpact();
        final created = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceFormPage(existing: {}, service: {},),
            fullscreenDialog: true,
          ),
        );
        if (created == true) {
          _fetchAll();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("Service created successfully"),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        }
      },
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
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

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الصف العلوي: الصورة والمعلومات الأساسية
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الصورة
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF1F5F9),
                  ),
                  child: cover != null && cover.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: const Color(0xFF62C6D9),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.image,
                              color: Colors.grey[400],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.image,
                          color: Colors.grey[400],
                        ),
                ),
                const SizedBox(width: 12),

                // المعلومات
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // العنوان والباج
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border:
                                  Border.all(color: badgeColor.withOpacity(0.3)),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // الفئة
                      Text(
                        category,
                        style: TextStyle(
                          color: const Color(0xFF62C6D9),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // الإحصائيات السريعة
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildStatChip(
                            Icons.attach_money,
                            "${price.toStringAsFixed(0)} $currency",
                          ),
                          _buildStatChip(
                            Icons.schedule,
                            "$duration min",
                          ),
                          if (rating > 0)
                            _buildStatChip(
                              Icons.star,
                              rating.toStringAsFixed(1),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // صف الإحصائيات التفصيلية
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDetailStat(
                    "Bookings",
                    "$bookings",
                    Icons.event_available,
                  ),
                  if (rating > 0) ...[
                    const SizedBox(width: 16),
                    _buildDetailStat(
                      "Rating",
                      "${rating.toStringAsFixed(1)} ($ratingCount)",
                      Icons.star,
                    ),
                  ],
                  const SizedBox(width: 16),
                  _buildDetailStat(
                    "Price",
                    "${price.toStringAsFixed(2)} $currency",
                    Icons.attach_money,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // أزرار التحكم
            _buildActionButtons(sv, isPublished, isArchived),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    Map<String, dynamic> sv,
    bool isPublished,
    bool isArchived,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;

    // قائمة الأزرار
    final List<Map<String, dynamic>> buttons = [
      {
        'icon': Icons.remove_red_eye,
        'label': 'Preview',
        'action': () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ServicePublicPreviewPage(serviceId: sv['_id'], service: {}),
              ),
            ),
      },
      {
        'icon': Icons.copy,
        'label': 'Duplicate',
        'action': () => _duplicate(sv['_id']),
      },
      {
        'icon': Icons.edit,
        'label': 'Edit',
        'action': () async {
          final updated = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ServiceFormPage(existing: sv, service: {},),
            ),
          );
          if (updated == true) _fetchAll();
        },
      },
      {
        'icon': isPublished ? Icons.visibility_off : Icons.visibility,
        'label': isPublished ? 'Hide' : 'Publish',
        'action': () => _togglePublish(sv['_id'], !isPublished),
        'color': isPublished ? Colors.orange : Colors.green,
      },
      {
        'icon': isArchived ? Icons.unarchive : Icons.archive,
        'label': isArchived ? 'Restore' : 'Archive',
        'action': () => isArchived
            ? _unarchive(sv['_id'])
            : _archive(sv['_id']),
        'isDanger': !isArchived,
      },
    ];

    if (screenWidth < 400) {
      // للشاشات الصغيرة: أزرار عمودية
      return Column(
        children: buttons.map((btn) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              onPressed: btn['action'] as VoidCallback,
              icon: Icon(
                btn['icon'] as IconData,
                size: 16,
                color: (btn['isDanger'] as bool?) == true
                    ? Colors.redAccent
                    : (btn['color'] ?? const Color(0xFF62C6D9)),
              ),
              label: Text(
                btn['label'] as String,
                style: TextStyle(
                  fontSize: 12,
                  color: (btn['isDanger'] as bool?) == true
                      ? Colors.redAccent
                      : (btn['color'] ?? const Color(0xFF62C6D9)),
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: ((btn['isDanger'] as bool?) == true
                          ? Colors.redAccent
                          : (btn['color'] ?? const Color(0xFF62C6D9)))
                      .withOpacity(0.3),
                ),
              ),
            ),
          );
        }).toList(),
      );
    } else {
      // للشاشات المتوسطة والكبيرة: أزرار أفقية مع تمرير
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: buttons.map((btn) {
            return Container(
              margin: const EdgeInsets.only(right: 6),
              child: OutlinedButton.icon(
                onPressed: btn['action'] as VoidCallback,
                icon: Icon(
                  btn['icon'] as IconData,
                  size: 16,
                  color: (btn['isDanger'] as bool?) == true
                      ? Colors.redAccent
                      : (btn['color'] ?? const Color(0xFF62C6D9)),
                ),
                label: Text(
                  btn['label'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: (btn['isDanger'] as bool?) == true
                        ? Colors.redAccent
                        : (btn['color'] ?? const Color(0xFF62C6D9)),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  side: BorderSide(
                    color: ((btn['isDanger'] as bool?) == true
                            ? Colors.redAccent
                            : (btn['color'] ?? const Color(0xFF62C6D9)))
                        .withOpacity(0.3),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }
  }
}