// lib/pages/customer_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_profile_page.dart';
import 'ExpertDetailPage.dart';
import 'customer_notifications_page.dart';
import 'customer_messages_page.dart';
import 'customer_help_page.dart';
import 'customer_calendar_page.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loading = true;
  //////
late PageController _expertsPageController;
double _expertsPage = 0.0;
///////
  static const Color primaryColor = Color(0xFF62C6D9);
  static const Color accentColor = Color(0xFF285E6E);
  static const baseUrl = "http://localhost:5000";

  late AnimationController _hoverController;

  List<dynamic> experts = [];
  bool loadingExperts = true;

  // 🔎 حالة السيرش / الفلترة
  String _searchQuery = '';
  String? _selectedCategory; // null = All
  String _sortBy = 'RATING_DESC'; // RATING_DESC, PRICE_ASC, PRICE_DESC
  bool _searching = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _searchResults = [];

  final List<String> _categories = const [
    "Design",
    "Programming",
    "Consulting",
    "Marketing",
    "Education",
    "Translation",
    "Other",
  ];

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    ///////
    _expertsPageController = PageController(viewportFraction: 0.78);

_expertsPageController.addListener(() {
  setState(() {
    _expertsPage = _expertsPageController.page ?? 0.0;
  });
});
/////////
    
    fetchUser();
    fetchExperts();
  }

 @override
void dispose() {
  _hoverController.dispose();
  _expertsPageController.dispose();
  super.dispose();
}


  Future<void> fetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      setState(() => loading = false);
      return;
    }

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => user = data['user']);
      } else {
        debugPrint('Failed to fetch user: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> fetchExperts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse('$baseUrl/api/public/experts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          experts = (data['experts'] ?? []) as List<dynamic>;
          loadingExperts = false;
        });
      } else {
        debugPrint("Failed to load experts: ${res.statusCode}");
        setState(() => loadingExperts = false);
      }
    } catch (e) {
      debugPrint("Error loading experts: $e");
      setState(() => loadingExperts = false);
    }
  }

  List<Map<String, dynamic>> getRecommendedExperts() {
    return [
      {"name": "Dr. Lina Saleh", "specialty": "UX/UI Design", "rating": 4.9},
      {"name": "Eng. Rami Khaled", "specialty": "Backend Node.js", "rating": 4.7},
      {"name": "Ms. Sara Fadi", "specialty": "Marketing Strategy", "rating": 4.8},
    ];
  }

  /* ----------------------------------------------------
   * 🔍 API بحث عن الخدمات (Service + Expert)
   * ---------------------------------------------------- */
  Future<void> _searchServices() async {
    setState(() {
      _searching = true;
      _hasSearched = true;
      _searchResults.clear();
    });

    try {
      final params = <String, String>{};
      if (_searchQuery.trim().isNotEmpty) {
        params['q'] = _searchQuery.trim();
      }
      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        params['category'] = _selectedCategory!;
      }

      switch (_sortBy) {
        case 'PRICE_ASC':
          params['sort'] = 'price_asc';
          break;
        case 'PRICE_DESC':
          params['sort'] = 'price_desc';
          break;
        default:
          params['sort'] = 'rating_desc';
      }

      final uri = Uri.parse('$baseUrl/api/public/services/search')
          .replace(queryParameters: params);

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final items = (data['items'] ?? []) as List<dynamic>;
        setState(() {
          _searchResults = items
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        });
      } else {
        debugPrint("Search failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Search error: $e");
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

 @override
Widget build(BuildContext context) {
  final String userName =
      user?['name'] ?? user?['email']?.split('@')[0] ?? 'User';

  return Scaffold(
    backgroundColor: const Color(0xFFF3F7FA),
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: _buildTopBar(userName),
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: accentColor,
      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      label: const Text("Chatbot", style: TextStyle(color: Colors.white)),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("🤖 AI Chatbot coming soon...")),
        );
      },
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await fetchUser();
              await fetchExperts();
              if (_hasSearched) await _searchServices();
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1) Hero
                      ScrollReveal(
                        delay: const Duration(milliseconds: 0),
                        child: _buildWelcomeBanner(),
                      ),
                      const SizedBox(height: 24),

                      // 2) Search
                      ScrollReveal(
                        delay: const Duration(milliseconds: 120),
                        child: _buildSearchAndFilters(),
                      ),
                      const SizedBox(height: 24),

                      // 3) Results
                      ScrollReveal(
                        delay: const Duration(milliseconds: 220),
                        child: _buildSearchResultsSection(),
                      ),
                      const SizedBox(height: 32),

                      // 4) Recommended experts
                      ScrollReveal(
                        delay: const Duration(milliseconds: 320),
                        child: _buildRecommendedSectionCard(),
                      ),
                      const SizedBox(height: 24),

                      // 5) Experts Carousel
                      ScrollReveal(
                        delay: const Duration(milliseconds: 420),
                        child: _buildExpertsSectionCard(),
                      ),
                      const SizedBox(height: 24),

                      // 6) Categories
                      ScrollReveal(
                        delay: const Duration(milliseconds: 520),
                        child: _buildCategoriesSectionCard(),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );
}


  // ========================= TOP BAR =========================

  PreferredSizeWidget _buildTopBar(String userName) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white.withOpacity(0.96),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 28,
      shape: const Border(
        bottom: BorderSide(color: Color(0xFFE1E7EF), width: 1),
      ),
      title: Row(
        children: [
          // Logo داخل Capsule Gradient
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [primaryColor, accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Image.asset(
                'assets/images/treasure_icon.png',
                height: 22,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            "Lost Treasures",
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 30),

          // شريط بحث شكلي في الـ AppBar (غير مربوط بالـ API)
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAFD),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE0ECF4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: const [
                  Icon(Icons.search, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    "Search mentors, topics, or skills...",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  "Welcome back,",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  userName,
                  style: const TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFE3F6FA),
              child: Icon(Icons.person, color: accentColor, size: 20),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: "Notifications",
              icon: const Icon(Icons.notifications_none, color: accentColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerNotificationsPage(),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: "Messages",
              icon: const Icon(Icons.mail_outline, color: accentColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerMessagesPage(),
                  ),
                );
              },
            ),
                        IconButton(
              tooltip: "Help & Support",
              icon: const Icon(Icons.help_outline, color: accentColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerHelpPage(),
                  ),
                );
              },
            ),

            const SizedBox(width: 4),

            // 🔹 My Calendar tab (يفتح صفحة التقويم)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerCalendarPage()),
                );
              },
              child: const Text(
                "My Calendar",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 🔹 My Profile (زي ما هو لكن بعد الكالندر)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: accentColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerProfilePage(),
                  ),
                );
              },
              child: const Text(
                "My Profile",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 18),

          ],
        ),
      ],
    );
  }

  // ========================= UI SECTIONS =========================

 Widget _buildWelcomeBanner() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [
          Color(0xFF62C6D9),
          Color(0xFF3BA8B7),
          Color(0xFF287E8D),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 18,
          offset: Offset(0, 9),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Find the right mentor.\nBuild your future with confidence.",
                style: TextStyle(
                  fontSize: 26,
                  height: 1.3,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Book 1:1 sessions with verified experts in tech, design, business and more.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 14),
            ],
          ),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 180,
          height: 180,
          child: Image.asset(
            "assets/images/mentors_hero.png", // ✅ حضّري هذه الصورة في assets
            fit: BoxFit.contain,
          ),
        ),
      ],
    ),
  );
}


  /// 🔎 Search + Category + Sort
  Widget _buildSearchAndFilters() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Search for a Service",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF1F4A5A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Find the right session by topic, expert name, or keywords.",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (v) => _searchQuery = v,
                    onSubmitted: (_) => _searchServices(),
                    decoration: InputDecoration(
                      hintText:
                          "e.g. UI design review, Node.js help, marketing strategy...",
                      prefixIcon: const Icon(Icons.search,
                          color: primaryColor, size: 22),
                      filled: true,
                      fillColor: const Color(0xFFF7FBFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 13, horizontal: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _searchServices,
                  child: const Text(
                    "Search",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                // Category
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: "Category",
                      filled: true,
                      fillColor: const Color(0xFFF7FBFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text("All categories"),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedCategory = v);
                      if (_hasSearched) _searchServices();
                    },
                  ),
                ),
                const SizedBox(width: 14),
                // Sort
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _sortBy,
                    decoration: InputDecoration(
                      labelText: "Sort by",
                      filled: true,
                      fillColor: const Color(0xFFF7FBFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'RATING_DESC',
                        child: Text("Top rated"),
                      ),
                      DropdownMenuItem(
                        value: 'PRICE_ASC',
                        child: Text("Price: low to high"),
                      ),
                      DropdownMenuItem(
                        value: 'PRICE_DESC',
                        child: Text("Price: high to low"),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _sortBy = v ?? 'RATING_DESC');
                      if (_hasSearched) _searchServices();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔎 عرض نتائج البحث عن الخدمات
  Widget _buildSearchResultsSection() {
    if (!_hasSearched && _searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_searching) {
      return const Padding(
        padding: EdgeInsets.only(top: 8.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_searchResults.isEmpty) {
      return Card(
        margin: const EdgeInsets.only(top: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 2,
        child: const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "No services match your search yet.\nTry a different keyword or category.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "Search results (${_searchResults.length})",
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 10),
       SizedBox(
  height: 170,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: _searchResults.length,
    separatorBuilder: (_, __) => SizedBox(width: 16),
    itemBuilder: (context, index) {
      return SizedBox(
        width: 320,
        child: _buildServiceSearchCard(_searchResults[index]),
      );
    },
  ),
)

      ],
    );
  }

  Widget _buildServiceSearchCard(Map<String, dynamic> service) {
    // ====== جلب بيانات الخدمة ======
    final title = (service['title'] ?? 'Untitled').toString();
    final category = (service['category'] ?? 'General').toString();
    final price = service['price'] ?? 0;
    final currency = (service['currency'] ?? 'USD').toString();
    final rating = (service['ratingAvg'] ?? 0).toDouble();

    // ====== دمج بيانات الخبير + بروفايل الخبير ======
    final expert = service['expert'] ?? {};
    final profile = service['expertProfile'] ?? {};

    final expertName =
        (expert['name'] ?? profile['name'] ?? 'Expert').toString();

    final expertImg =
        (expert['profileImageUrl'] ?? profile['profileImageUrl'] ?? '')
            .toString();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3EDF4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ====== صورة الخبير ======
            CircleAvatar(
              radius: 26,
              backgroundColor: primaryColor.withOpacity(0.1),
              backgroundImage:
                  expertImg.isNotEmpty ? NetworkImage(expertImg) : null,
              child: expertImg.isEmpty
                  ? const Icon(Icons.person, color: primaryColor)
                  : null,
            ),
            const SizedBox(width: 12),

            // ====== تفاصيل الخدمة ======
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Color(0xFF285E6E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "$category • by $expertName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.attach_money,
                          size: 16, color: Colors.grey),
                      Text(
                        "$price $currency",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.star,
                          size: 16, color: Colors.amber),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // ====== زر Book ======
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(80, 36),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExpertDetailPage(
                      expert: {
                        ...expert,
                        ...profile,
                      },
                    ),
                  ),
                );
              },
              child: const Text(
                "Book",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================= SIDE CARDS =========================

  Widget _buildRecommendedSectionCard() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _buildRecommendedSection(),
      ),
    );
  }

  Widget _buildExpertsSectionCard() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _buildShowExpertsSection(),
      ),
    );
  }

  Widget _buildCategoriesSectionCard() {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _buildCategorySection(),
      ),
    );
  }

  // ========================= EXISTING SECTIONS (مع تحسين بسيط) =========================

  Widget _buildRecommendedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "💡 Recommended Experts For You",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: getRecommendedExperts()
                .map((expert) => _buildExpertCard(expert))
                .toList(),
          ),
        ),
      ],
    );
  }

Widget _buildShowExpertsSection() {
  if (loadingExperts) {
    return const Center(child: CircularProgressIndicator());
  }
  if (experts.isEmpty) {
    return const Text(
      "No experts found right now.",
      style: TextStyle(color: Colors.grey),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "👨‍🏫 Meet Our Experts",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
      const SizedBox(height: 14),

      SizedBox(
  height: 190,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemBuilder: (context, index) {
      final expert = experts[index] as Map<String, dynamic>;
      return _buildExpertCard(expert);
    },
    separatorBuilder: (_, __) => SizedBox(width: 16),
    itemCount: experts.length,
  ),
)


    ],
  );
}


Widget _buildExpertCard(Map<String, dynamic> expert) {
  final name = (expert["name"] ?? "Unknown").toString();
  final specialty =
      (expert["specialization"] ?? expert["specialty"] ?? "N/A").toString();
  final ratingVal =
      (expert["ratingAvg"] ?? expert["rating"] ?? 0).toString();
  final profileImageUrl = (expert["profileImageUrl"] ?? "").toString();

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 16),
      width: 130,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

        // 🔥 ظل تركوازي مشع + 3D
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF62C6D9).withOpacity(0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE9F5F7),
          width: 1,
        ),
      ),

      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // ===== صورة الخبير =====
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF62C6D9),
                    Color(0xFF3BA8B7),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: profileImageUrl.isEmpty
                    ? const Icon(Icons.person,
                        size: 28, color: Color(0xFF62C6D9))
                    : null,
              ),
            ),

            const SizedBox(height: 10),

            // ===== الاسم =====
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Color(0xFF285E6E),
              ),
            ),

            // ===== التخصص =====
            Text(
              specialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            const Spacer(),

            // ===== التقييم + View =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star,
                        size: 15, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(
                      ratingVal,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                // ===== زر View =====
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF62C6D9),
                        Color(0xFF3BA8B7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(55, 28),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExpertDetailPage(expert: expert),
                        ),
                      );
                    },
                    child: const Text(
                      "View",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}


Widget _buildCategorySection() {
  final categories = [
    //{"title": "Technology", "icon": Icons.code},
    {"title": "Design", "icon": Icons.palette},
   // {"title": "Business", "icon": Icons.business_center},
    {"title": "Education", "icon": Icons.school},
    {"title": "Marketing", "icon": Icons.campaign},
    {"title": "Consulting", "icon": Icons.support_agent},
    {"title": "Translation", "icon": Icons.language},
    {"title": "Other", "icon": Icons.apps},
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Browse Specialties",
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Color(0xFF285E6E),
        ),
      ),
      const SizedBox(height: 20),

      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 3.8, // 🔥 أصغر وأرتب
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,

              // ===== UI BOX =====
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                boxShadow: [
                  // 🔥 Turquoise glow shadow
                  BoxShadow(
                    color: const Color(0xFF62C6D9).withOpacity(0.30),
                    blurRadius: 28,
                    spreadRadius: -2,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFFE8F5F8),
                  width: 1,
                ),
              ),

              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  setState(() {
                    _selectedCategory = cat["title"] as String;
                    _hasSearched = true;
                  });
                  _searchServices();
                },

                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),

                  child: Row(
                    children: [
                      // ===== ICON BUBBLE =====
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF62C6D9),
                              Color(0xFF3BA8B7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Icon(
                          cat["icon"] as IconData,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(width: 14),

                      // ===== Text label =====
                      Expanded(
                        child: Text(
                          cat["title"] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF285E6E),
                          ),
                        ),
                      ),

                      // ===== Arrow right =====
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey,
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );
}


    }
  class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const ScrollReveal({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 0),
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}
    
class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    // يبدأ الأنيميشن بعد التأخير المحدد
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}




