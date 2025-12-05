import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'customer_profile_page.dart';
import 'ExpertDetailPage.dart';
import '/pages/search_page.dart';
import 'chatbot_widget.dart';

// ---------------- GLOBAL COLORS ----------------
const Color primaryColor = Color(0xFF62C6D9);
const Color darkColor = Color(0xFF1D5C68);

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loading = true;

  static const baseUrl = "http://localhost:5000";

  List<dynamic> experts = [];
  List<dynamic> services = [];

  // 3D Pointer
  Offset pointer = Offset.zero;

  // VIDEO
  late VideoPlayerController videoController;

  // HERO
  late AnimationController heroController;
  late Animation<double> heroScale;
  late Animation<double> heroOpacity;

  // SCROLL
  final ScrollController _expertScrollController = ScrollController();

  // PROMO CAROUSEL
  PageController promoController = PageController(viewportFraction: 0.90);
  int currentPromo = 0;

  // FLOATING PARTICLES
  List<Offset> particles = [];
  final int particleCount = 20;
  final Random random = Random();

  @override
  void initState() {
    super.initState();

    fetchUser();
    fetchExperts();
  fetchServices();
    // HERO animation
    heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    heroScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: heroController, curve: Curves.elasticOut),
    );

    heroOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: heroController, curve: Curves.easeOut),
    );

    heroController.forward();

    // VIDEO INIT
    videoController = VideoPlayerController.asset("assets/hero_bg.mp4")
      ..initialize().then((_) {
        videoController.setLooping(true);
        videoController.setVolume(0);
        videoController.play();
        setState(() {});
      });

    // PROMO auto slide
    Future.delayed(const Duration(seconds: 1), () {
      Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!mounted || !promoController.hasClients) return;
        currentPromo = (currentPromo + 1) % 3;
        promoController.animateToPage(
          currentPromo,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuad,
        );
      });
    });

    // PARTICLES init
    for (int i = 0; i < particleCount; i++) {
      particles.add(
        Offset(
          random.nextDouble() * 400,
          random.nextDouble() * 300,
        ),
      );
    }

    Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        particles = particles.map((p) {
          double dx = p.dx + (random.nextDouble() * 2 - 1);
          double dy = p.dy + (random.nextDouble() * 2 - 1);
          return Offset(dx, dy);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    heroController.dispose();
    videoController.dispose();
    super.dispose();
  }
Future<void> fetchServices() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token") ?? "";

    final res = await http.get(
      Uri.parse("$baseUrl/api/services"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      services = List.from(data["services"] ?? []);
      print("SERVICES LOADED → ${services.length}");
    } else {
      print("FAILED TO LOAD SERVICES: ${res.statusCode}");
    }
  } catch (e) {
    print("ERROR FETCHING SERVICES: $e");
  }

  setState(() {});
}
 // ---------------- FETCH USER ----------------
  Future<void> fetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        setState(() => user = backendSafe(jsonDecode(res.body)["user"]));
      }
    } catch (_) {}

    setState(() => loading = false);
  }

  Map<String, dynamic> backendSafe(dynamic data) {
    return data is Map<String, dynamic> ? data : {};
  }

  // ---------------- FETCH EXPERTS ----------------
  Future<void> fetchExperts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$baseUrl/api/public/experts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        experts = backendSafe(jsonDecode(res.body))["experts"] ?? [];
      }
    } catch (_) {}

    setState(() {});
  }

  // STRONG SLIDE
  Widget strongSlide({required Widget child, int delay = 0}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 80, end: 0),
      duration: Duration(milliseconds: 650 + delay),
      curve: Curves.decelerate,
      builder: (context, double value, _) {
        return Transform.translate(
          offset: Offset(0, value),
          child: Opacity(opacity: 1 - (value / 80), child: child),
        );
      },
    );
  }

  // BACKGROUND LAYER
  Widget _buildBackgroundLayer() {
    return Stack(
      children: [
        if (videoController.value.isInitialized)
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: videoController.value.size.width,
                height: videoController.value.size.height,
                child: VideoPlayer(videoController),
              ),
            ),
          ),

        Container(color: Colors.white.withOpacity(0.35)),

        CustomPaint(
          size: Size.infinite,
          painter: ParticlePainter(particles: particles),
        ),
      ],
    );
  }

  // ---------------- BUILD UI ----------------
  @override
  Widget build(BuildContext context) {
    String name = user?['name'] ?? "Guest";

    return Stack(
      children: [
        _buildBackgroundLayer(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: _buildAppBar(name),
          floatingActionButton: _buildChatbotButton(),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : MouseRegion(
                  onHover: (e) => setState(() => pointer = e.localPosition),
                  child: _buildMainContent(),
                ),
        ),
      ],
    );
  }

  // MAIN CONTENT
  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          strongSlide(child: _buildPROHeroBanner(), delay: 0),
          const SizedBox(height: 20),
          strongSlide(child: _buildPromoCarousel(), delay: 150),
          const SizedBox(height: 25),
          strongSlide(child: _buildSearchBar(), delay: 250),
          const SizedBox(height: 20),
          strongSlide(child: _buildFilters(), delay: 350),
          const SizedBox(height: 22),
          strongSlide(child: _buildStats(), delay: 450),
          const SizedBox(height: 30),
          strongSlide(child: _buildRecommendedSection(), delay: 550),
          const SizedBox(height: 25),
          strongSlide(child: _buildExpertsSection(), delay: 650),
          const SizedBox(height: 25),
          strongSlide(child: _buildSpecialtiesSection(), delay: 750),
          const SizedBox(height: 25),
          strongSlide(child: _buildHowItWorksSection(), delay: 850),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
  // ---------------- APP BAR ----------------
  AppBar _buildAppBar(String name) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      title: Text(
        "Welcome, $name 👋",
        style: const TextStyle(
          fontSize: 19,
          color: Colors.black87,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: Colors.white, blurRadius: 4),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: Colors.black87),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
            );
          },
        ),
      ],
    );
  }

  // ---------------- CHATBOT BUTTON ----------------
  Widget _buildChatbotButton() {
    return FloatingActionButton(
      backgroundColor: primaryColor,
      elevation: 6,
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const ChatBotWidget(),
        );
      },
    );
  }

  // ---------------- HERO BANNER PRO (3D PARALLAX) ----------------
 // ---------------- HERO BANNER PRO (STATIC) ----------------
Widget _buildPROHeroBanner() {
  return Transform(
    alignment: Alignment.center,
    // نترك فقط الـ scale animation (إذا بدك ألغيه خبريني)
    transform: Matrix4.identity()..scale(heroScale.value),
    child: Opacity(
      opacity: heroOpacity.value,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF00B4DB),
              Color(0xFF0083B0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Upgrade Your Career 🚀",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Find top mentors, book 1-on-1 sessions, and grow faster.",
              style: TextStyle(
                fontSize: 15,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
 Widget _buildPromoCarousel() {
  final promos = [
    {
      "title": "🔥 Level Up Faster",
      "image": "https://picsum.photos/300/300?random=1",
      "color": Colors.blueAccent
    },
    {
      "title": "🎯 Learn From Top Mentors",
      "image": "https://picsum.photos/300/300?random=2",
      "color": Colors.deepPurple
    },
    {
      "title": "🚀 Boost Your Skills Today",
      "image": "https://picsum.photos/300/300?random=3",
      "color": Colors.teal
    },
  ];

  return SizedBox(
    height: 110,
    child: PageView.builder(
      controller: promoController,
      itemCount: promos.length,
      itemBuilder: (context, i) {
        bool active = i == currentPromo;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          margin: EdgeInsets.symmetric(horizontal: active ? 6 : 22),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                (promos[i]["color"] as Color).withOpacity(0.9),
                (promos[i]["color"] as Color).withOpacity(0.6),
              ],
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  promos[i]["title"].toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),

              AnimatedScale(
                scale: active ? 1.1 : 0.9,
                duration: const Duration(milliseconds: 600),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    promos[i]["image"].toString(),
                    height: 90,
                    width: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      onPageChanged: (i) => setState(() => currentPromo = i),
    ),
  );
}
 // ---------------- SEARCH BAR — PRO ----------------
  Widget _buildSearchBar() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SearchPage(
       
            ),
          ),
        );
      },
      child: TweenAnimationBuilder(
        duration: const Duration(milliseconds: 500),
        tween: Tween<double>(begin: 0.7, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, double value, child) {
          return Transform.scale(
            scale: value,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(35),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.search, size: 26, color: darkColor),
                      SizedBox(width: 14),
                      Text(
                        "Search experts or services...",
                        style: TextStyle(color: Colors.black54, fontSize: 16),
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

  // ---------------- FILTERS ----------------
  Widget _buildFilters() {
    final filters = ["Popular", "Top Rated", "New Experts", "Available Now"];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          return TweenAnimationBuilder(
            tween: Tween<double>(begin: 0.7, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, double value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Center(
                child: Text(
                  filters[i],
                  style: const TextStyle(
                    fontSize: 13,
                    color: darkColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  // ---------------- STATS ----------------
  Widget _buildStats() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _statItem(title: "Experts", value: "120+"),
            _statItem(title: "Sessions", value: "2.3K"),
            _statItem(title: "Rating", value: "4.8"),
          ],
        ),
      ),
    );
  }

  // ---------------- RECOMMENDED ----------------
  Widget _buildRecommendedSection() {
    final demo = [
      {"name": "Dr. Lina Saleh", "specialty": "UI/UX Design", "rating": "4.9"},
      {"name": "Eng. Rami Khaled", "specialty": "Node.js Backend", "rating": "4.7"},
      {"name": "Sara Fadi", "specialty": "Marketing", "rating": "4.8"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("💡 Recommended For You"),
        const SizedBox(height: 12),

        SizedBox(
          height: 210,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: demo.map((e) => _buildExpertCard(e)).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------- EXPERTS SECTION ----------------
  Widget _buildExpertsSection() {
    if (experts.isEmpty) {
      return const Text(
        "No experts available",
        style: TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("👨‍🏫 Meet Our Experts"),
        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _arrowButton(Icons.arrow_back_ios, false),
            const SizedBox(width: 12),
            _arrowButton(Icons.arrow_forward_ios, true),
          ],
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 220,
          child: ListView.builder(
            controller: _expertScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: experts.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, i) => _buildExpertCard(experts[i]),
          ),
        ),
      ],
    );
  }

  // ---------------- EXPERT CARD — PRO MAX ----------------
  Widget _buildExpertCard(Map<String, dynamic> expert) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, double scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },

      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpertDetailPage(expert: expert),
            ),
          );
        },

        child: Container(
          width: 180,
          margin: const EdgeInsets.only(right: 18),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------- PROFILE PIC --------
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(seconds: 2),
                      height: 68,
                      width: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withOpacity(0.12),
                      ),
                    ),

                    CircleAvatar(
                      radius: 28,
                      backgroundColor: primaryColor,
                      backgroundImage: expert["profileImageUrl"] != null &&
                              expert["profileImageUrl"].toString().isNotEmpty
                          ? NetworkImage(expert["profileImageUrl"])
                          : null,
                      child: (expert["profileImageUrl"] ?? "").toString().isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 28)
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // -------- NAME --------
              Text(
                expert["name"] ?? "Unknown",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              // -------- SPECIALIZATION --------
              Text(
                expert["specialization"] ?? "N/A",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),

              const Spacer(),

              // -------- FOOTER --------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, size: 16, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        (expert["ratingAvg"] ?? "0").toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
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
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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

  // ---------------- SPECIALTIES SECTION — PRO ----------------
  Widget _buildSpecialtiesSection() {
    final List<Map<String, dynamic>> categories = [
      {"title": "Technology", "icon": Icons.code},
      {"title": "Design", "icon": Icons.palette},
      {"title": "Business", "icon": Icons.business_center},
      {"title": "Education", "icon": Icons.school},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("Browse Specialties"),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
     itemBuilder: (_, i) {
  final cat = categories[i];

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SearchPage(
            preselectedCategory: cat["title"], // إرسال التخصص
          ),
        ),
      );
    },
    child: TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, double value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.78),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(cat["icon"] as IconData,
                    size: 22, color: primaryColor),
                const SizedBox(width: 12),
                Text(
                  cat["title"],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
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
  // ---------------- HOW IT WORKS — PRO ----------------
  Widget _buildHowItWorksSection() {
    final steps = [
      {
        "icon": Icons.search,
        "title": "1. Find a mentor",
        "subtitle": "Search by skills and experience."
      },
      {
        "icon": Icons.calendar_today,
        "title": "2. Book a session",
        "subtitle": "Choose a suitable time."
      },
      {
        "icon": Icons.star,
        "title": "3. Improve yourself",
        "subtitle": "Learn directly from top mentors."
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle("How it works"),
        const SizedBox(height: 16),

        Column(
          children: List.generate(steps.length, (i) {
            final s = steps[i];

            return TweenAnimationBuilder(
              tween: Tween<double>(begin: 60, end: 0),
              duration: Duration(milliseconds: 550 + (i * 120)),
              curve: Curves.easeOutCubic,
              builder: (context, double value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: Opacity(
                    opacity: 1 - (value / 60),
                    child: child,
                  ),
                );
              },

              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: primaryColor.withOpacity(0.15),
                          child: Icon(
                            s["icon"] as IconData,
                            size: 20,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (s["title"] ?? "").toString(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                (s["subtitle"] ?? "").toString(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  // ---------------- SECTION TITLE ----------------
  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w900,
        color: darkColor,
      ),
    );
  }

  // ---------------- ARROW BUTTONS ----------------
  Widget _arrowButton(IconData icon, bool forward) {
    return GestureDetector(
      onTap: () {
        double offset = forward
            ? _expertScrollController.offset + 260
            : _expertScrollController.offset - 260;

        _expertScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
        );
      },
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        builder: (context, double value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.90),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Icon(icon, size: 18, color: primaryColor),
        ),
      ),
    );
  }
}

// ---------------- STAT ITEM ----------------
class _statItem extends StatelessWidget {
  final String title;
  final String value;

  const _statItem({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}

// ---------------- PARTICLE PAINTER ----------------
class ParticlePainter extends CustomPainter {
  final List<Offset> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final p in particles) {
      canvas.drawCircle(p, 3, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
