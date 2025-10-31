import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import './customer_profile_page.dart';
import './ExpertDetailPage.dart'; // اضيفي صفحة الخبير هنا

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
} 

class _CustomerHomePageState extends State<CustomerHomePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loading = true;

  static const Color primaryColor = Color(0xFF62C6D9);
  static const Color accentColor = Color(0xFF285E6E);
  static const baseUrl = "http://localhost:5000";

  late AnimationController _hoverController;

  List<dynamic> experts = [];
  bool loadingExperts = true;

  @override
  void initState() {
    super.initState();
    _hoverController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    fetchUser();
    fetchExperts();
  }

  @override
  void dispose() {
    _hoverController.dispose();
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
        Uri.parse('$baseUrl/api/customers/experts'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          experts = data['experts'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    String userName = user?['name'] ?? user?['email']?.split('@')[0] ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFC),
      appBar: AppBar(
        elevation: 2,
        backgroundColor: primaryColor,
        title: Text(
          "Welcome, $userName 👋",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CustomerProfilePage()),
              );
            },
          ),
        ],
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
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeBanner(),
                    const SizedBox(height: 25),
                    _buildSearchBar(),
                    const SizedBox(height: 25),
                    _buildRecommendedSection(),
                    const SizedBox(height: 25),
                    _buildShowExpertsSection(),
                    const SizedBox(height: 30),
                    _buildCategorySection(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [Color(0xFF62C6D9), Color(0xFF43A6B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Find Your Mentor\nAnd Grow Professionally!",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "Connect with top-rated experts for mentorship and guidance across all fields.",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: "Search by specialty, skill, or name...",
        prefixIcon: const Icon(Icons.search, color: primaryColor),
        suffixIcon: IconButton(
          icon: const Icon(Icons.filter_list, color: primaryColor),
          onPressed: () {},
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
    );
  }

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
        const SizedBox(height: 10),
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
      return const Text("No experts found right now.", style: TextStyle(color: Colors.grey));
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
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: experts.length,
            itemBuilder: (context, index) {
              final expert = experts[index];
              return _buildExpertCard({
                "name": expert["name"] ?? "Unknown",
                "specialty": expert["specialization"] ?? "N/A",
                "rating": 4.5,
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpertCard(Map<String, dynamic> expert) {
    return MouseRegion(
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: AnimatedScale(
        scale: 1.02,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 160,
          margin: const EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: primaryColor,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  expert["name"],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  expert["specialty"],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 5),
                        Text(
                          expert["rating"].toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(60, 30),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpertDetailPage(expert: expert),
                          ),
                        );
                      },
                      child: const Text("Booking", style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final categories = [
      {"title": "Technology", "icon": Icons.code},
      {"title": "Design", "icon": Icons.palette},
      {"title": "Business", "icon": Icons.business_center},
      {"title": "Education", "icon": Icons.school},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Browse Specialties",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.6,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: 1.0,
                child: Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(cat["icon"] as IconData, color: primaryColor),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              cat["title"] as String,
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
}