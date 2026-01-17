// lib/pages/customer_dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'customer_profile_page.dart';
import 'ExpertDetailPage.dart';
import 'customer_notifications_page.dart';
import 'customer_my_bookings_page.dart';
import 'customer_help_page.dart';
import 'customer_calendar_page.dart';
import 'chat/conversations_page.dart';
import 'customer_experts_page.dart';
import 'package:flutter_app/widgets/ai_assistant_panel.dart';
import '../config/api_config.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loading = true;

  bool _showOnlyTopRated = false; // Recommended top rated
  late PageController _expertsPageController;
  double _expertsPage = 0.0;
  bool _showOnlyTopRatedGeneral = false; // Meet our experts top rated
  bool _showOnlyTopRatedRecommended = false; // 🔴 جديد: للـ Recommended

  static const Color primaryColor = Color(0xFF62C6D9);
  static const Color accentColor = Color(0xFF285E6E);
  static String get baseUrl => ApiConfig.baseUrl;

  late AnimationController _hoverController;
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  List<dynamic> experts = [];
  bool loadingExperts = true;

  // 🔎 Search state
  String _searchQuery = '';
  String _selectedCategory = 'ALL'; // ✅ FIXED: بدل null
  String _sortBy = 'RATING_DESC';
  bool _searching = false;
  bool _hasSearched = false;
  List<Map<String, dynamic>> _searchResults = [];

  bool _showAiAssistant = false;

  int _bottomNavIndex = 0;

  final List<String> _categories = const [
    "Design",
    "Programming",
    "Consulting",
    "Marketing",
    "Education",
    "Translation",
    "Other",
  ];

  // --- interests ---
  List<String> _userInterests = [];
  bool _interestsLoaded = false;

  // ✅ Guest mode
  bool get isGuest => user == null;

  // ✅ Guard: require login
  void _requireLogin(VoidCallback action) {
    if (isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You need to login first"),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.pushNamed(context, '/login_page');
      return;
    }
    action();
  }

  // دالة لتسجيل الخروج
  Future<void> _logoutUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_interests');
      
      // إعادة توجيه إلى صفحة الـlanding page
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          '/landing_page', 
          (route) => false
        );
      }
    }
  }

  // دالة للتعامل مع ضغط الـHome
  void _handleHomePress() {
    if (isGuest) {
      Navigator.pushNamedAndRemoveUntil(
        context, 
        '/landing_page', 
        (route) => false
      );
    } else {
      // إذا كان مسجلاً، يبقى في نفس الصفحة
      _scrollTo(_homeKey);
    }
  }

  // دالة لتحديث الاهتمامات
  Future<void> _updateInterests(List<String> newInterests) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_interests', newInterests);

    setState(() {
      _userInterests = newInterests;
      _interestsLoaded = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF4CAF50),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Interests updated! ${newInterests.length} interests saved.",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // --- Interests dialog (improved responsive) ---
  void _showInterestsSelection() {
    final List<Map<String, dynamic>> interests = [
      {
        "title": "Design",
        "icon": Icons.palette,
        "color": const Color(0xFFE91E63),
        "description": "UI/UX, Graphic Design, Product Design"
      },
      {
        "title": "Programming",
        "icon": Icons.code,
        "color": const Color(0xFF2196F3),
        "description": "Web, Mobile, Backend Development"
      },
      {
        "title": "Marketing",
        "icon": Icons.trending_up,
        "color": const Color(0xFF4CAF50),
        "description": "Digital Marketing, Social Media, SEO"
      },
      {
        "title": "Consulting",
        "icon": Icons.business_center,
        "color": const Color(0xFF9C27B0),
        "description": "Business Strategy, Career Advice"
      },
      {
        "title": "Education",
        "icon": Icons.school,
        "color": const Color(0xFFFF9800),
        "description": "Teaching, Tutoring, Course Creation"
      },
      {
        "title": "Translation",
        "icon": Icons.translate,
        "color": const Color(0xFF009688),
        "description": "Language Services, Localization"
      },
      {
        "title": "Finance",
        "icon": Icons.attach_money,
        "color": const Color(0xFF795548),
        "description": "Investment, Financial Planning"
      },
      {
        "title": "Health & Wellness",
        "icon": Icons.favorite,
        "color": const Color(0xFFF44336),
        "description": "Fitness, Nutrition, Mental Health"
      },
    ];

    List<String> selectedInterests = List.from(_userInterests);

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.all(16),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = MediaQuery.of(context).size.width;
                final h = MediaQuery.of(context).size.height;

                final isSmall = w < 380;
                final dialogMaxH = h * 0.90; // بدون clamp


                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    maxHeight: dialogMaxH,
                  ),
                  child: Container(
                    width: w * 0.95,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 2,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          // ===== HEADER =====
                          Container(
                            padding: EdgeInsets.all(isSmall ? 18 : 24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFF62C6D9),
                                  Color(0xFF3BA8B7),
                                  Color(0xFF287E8D),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: isSmall ? 70 : 80,
                                  height: isSmall ? 70 : 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(Icons.interests,
                                      size: 38, color: Colors.white),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  "Let's personalize your experience!",
                                  style: TextStyle(
                                    fontSize: isSmall ? 18 : 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Select at least 3 interests to get personalized expert recommendations",
                                  style: TextStyle(
                                    fontSize: isSmall ? 12 : 14,
                                    color: Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          // ===== BODY (Scrollable) =====
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.all(isSmall ? 16 : 20),
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F9FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFE3F2FD)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: selectedInterests.length >= 3
                                                  ? const Color(0xFF4CAF50)
                                                  : const Color(0xFF62C6D9),
                                            ),
                                            child: Center(
                                              child: Text(
                                                selectedInterests.length.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Flexible(
                                            child: Text(
                                              selectedInterests.length >= 3
                                                  ? "Great! You're ready to go!"
                                                  : "Select ${3 - selectedInterests.length} more",
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: selectedInterests.length >= 3
                                                    ? const Color(0xFF4CAF50)
                                                    : const Color(0xFF285E6E),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: isSmall ? 1.05 : 1.25,
                                      ),
                                      itemCount: interests.length,
                                      itemBuilder: (context, index) {
                                        final interest = interests[index];
                                        final isSelected = selectedInterests
                                            .contains(interest['title']);

                                        return AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            color: isSelected
                                                ? interest['color'] as Color
                                                : Colors.white,
                                            border: Border.all(
                                              color: isSelected
                                                  ? interest['color'] as Color
                                                  : const Color(0xFFE0E0E0),
                                              width: isSelected ? 0 : 1,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color:
                                                          (interest['color'] as Color)
                                                              .withOpacity(0.35),
                                                      blurRadius: 18,
                                                      offset: const Offset(0, 8),
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.05),
                                                      blurRadius: 10,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(18),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              onTap: () {
                                                setState(() {
                                                  if (isSelected) {
                                                    selectedInterests
                                                        .remove(interest['title']);
                                                  } else {
                                                    selectedInterests.add(
                                                        interest['title']);
                                                  }
                                                });
                                              },
                                            child: Padding(
  padding: EdgeInsets.all(isSmall ? 10 : 14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.2)
                  : (interest['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              interest['icon'] as IconData,
              color: isSelected ? Colors.white : interest['color'] as Color,
              size: 20,
            ),
          ),
          const Spacer(),
          if (isSelected)
            Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: const Icon(
                Icons.check,
                size: 15,
                color: Color(0xFF4CAF50),
              ),
            ),
        ],
      ),

      SizedBox(height: isSmall ? 8 : 10),

      Text(
        interest['title'] as String,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isSmall ? 13 : 15,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : const Color(0xFF333333),
        ),
      ),

      const SizedBox(height: 6),

      // ✅ هذا أهم سطر: نخلي الوصف يتمدد ضمن المساحة بدل ما يطلع برا
      Expanded(
        child: Text(
          interest['description'] as String,
          maxLines: isSmall ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isSmall ? 10 : 11,
            height: 1.25,
            color: isSelected
                ? Colors.white.withOpacity(0.9)
                : const Color(0xFF666666),
          ),
        ),
      ),
    ],
  ),
),

                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // ===== FOOTER =====
                     // ===== FOOTER =====
Container(
  padding: EdgeInsets.all(isSmall ? 12 : 16),
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(
        color: Colors.grey.withOpacity(0.1),
        width: 1,
      ),
    ),
    color: Colors.white,
  ),
  child: isSmall
      ? Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Skip for now"),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: selectedInterests.length >= 3
                    ? () async {
                        Navigator.pop(context);
                        await _updateInterests(selectedInterests);
                      }
                    : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    selectedInterests.length >= 3
                        ? "Get Started!"
                        : "Select ${3 - selectedInterests.length} more",
                  ),
                ),
              ),
            ),
          ],
        )
      : Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Skip for now"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: selectedInterests.length >= 3
                      ? () async {
                          Navigator.pop(context);
                          await _updateInterests(selectedInterests);
                        }
                      : null,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      selectedInterests.length >= 3
                          ? "Get Started!"
                          : "Select ${3 - selectedInterests.length} more",
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
),
 
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserInterests() async {
    final prefs = await SharedPreferences.getInstance();
    final savedInterests = prefs.getStringList('user_interests');

    if (savedInterests != null) {
      setState(() {
        _userInterests = savedInterests;
        _interestsLoaded = true;
      });
    }
  }

  List<dynamic> _getFilteredExpertsByInterests() {
    if (experts.isEmpty || _userInterests.isEmpty) {
      return [];
    }

    final Set<String> seenExpertIds = {};
    List<dynamic> filteredExperts = [];

    final commonKeywords = {
      'programming': [
        'code', 'developer', 'software', 'web', 'mobile', 'backend', 'frontend',
        'flutter', 'full stack', 'fullstack', 'computer engineering', 'it',
        'software engineer', 'python', 'java', 'javascript', 'node', 'react', 'dart'
      ],
      'design': [
        'ui', 'ux', 'graphic', 'illustrator', 'designer', 'photoshop', 'creative',
        'branding', 'logo', 'figma', 'canva', 'art', 'adobe', 'sketch'
      ],
      'marketing': [
        'marketing', 'seo', 'ads', 'social media', 'digital marketing', 'content creator',
        'growth', 'sales', 'email marketing', 'copywriting', 'brand', 'advertising'
      ],
      'consulting': [
        'consulting', 'advisor', 'strategy', 'business', 'management', 'startup',
        'career', 'financial advisor', 'mentor', 'coach', 'leadership'
      ],
      'education': [
        'teacher', 'tutor', 'school', 'academic', 'instructor', 'teaching',
        'professor', 'training', 'course', 'education', 'lecturer'
      ],
      'translation': [
        'translator', 'translation', 'english', 'arabic', 'languages',
        'writing', 'editor', 'proofreading', 'language', 'localization'
      ],
      'finance': [
        'finance', 'financial', 'investment', 'accounting', 'banking', 'money',
        'stocks', 'trading', 'economy', 'wealth', 'tax'
      ],
      'health & wellness': [
        'health', 'wellness', 'fitness', 'nutrition', 'mental health', 'yoga',
        'therapy', 'coach', 'diet', 'exercise', 'meditation'
      ],
    };

 for (var expert in experts) {
  final String expertId =
      (expert['userId'] ?? expert['_id'] ?? expert['id'] ?? '').toString();

  if (expertId.isEmpty || seenExpertIds.contains(expertId)) {
    continue;
  }

      final String specialization = 
          (expert['specialization'] ?? '').toString().toLowerCase().trim();
      final String category = 
          (expert['category'] ?? '').toString().toLowerCase().trim();
      final String bio = 
          (expert['bio'] ?? expert['description'] ?? '').toString().toLowerCase().trim();

      bool isMatch = false;

      for (var interest in _userInterests) {
        final interestLower = interest.toLowerCase().trim();

        // مطابقة مباشرة
        if (specialization.contains(interestLower) ||
            category.contains(interestLower) ||
            bio.contains(interestLower)) {
          isMatch = true;
          break;
        }

        // مطابقة بالكلمات المشتركة
        if (commonKeywords.containsKey(interestLower)) {
          final keywords = commonKeywords[interestLower]!;
          if (keywords.any((keyword) =>
              specialization.contains(keyword) ||
              category.contains(keyword) ||
              bio.contains(keyword))) {
            isMatch = true;
            break;
          }
        }
      }

      if (isMatch) {
        filteredExperts.add(expert);
        seenExpertIds.add(expertId);
      }
    }

    // ترتيب حسب التقييم (الأعلى أولاً)
    filteredExperts.sort((a, b) {
      final dynamic ratingA = a['ratingAvg'];
      final dynamic ratingB = b['ratingAvg'];
      final double rA = ratingA is num ? ratingA.toDouble() : 0.0;
      final double rB = ratingB is num ? ratingB.toDouble() : 0.0;
      return rB.compareTo(rA);
    });

    // إذا كان فلتر Top Rated مفعل، نفلتر الخبراء ذو التقييم 4 فما فوق
    if (_showOnlyTopRatedRecommended) {
      filteredExperts = filteredExperts.where((e) {
        final dynamic ratingVal = e['ratingAvg'];
        final double rating = ratingVal is num ? ratingVal.toDouble() : 0.0;
        return rating >= 4.0;
      }).toList();
    }

    return filteredExperts;
  }

  // 🔴 🔴 🔴 قسم Recommended Experts مع Book Button
  Widget _buildRecommendedSection() {
    // ✅ Guest: لا نعرض recommended
    if (isGuest) return const SizedBox.shrink();

    final List<dynamic> filteredExperts = _getFilteredExpertsByInterests();

    if (!_interestsLoaded || _userInterests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        
        // 🔴 ROW مع العنوان + زر Edit Interests + زر Top Rated
        Row(
          children: [
            const Expanded(
              child: Text(
                "💡 Recommended Experts For You",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF285E6E),
                ),
              ),
            ),
            
            // زر Edit Interests (قلم)
            Tooltip(
              message: "Edit interests",
              child: IconButton(
                onPressed: () {
                  _showInterestsSelection();
                },
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF62C6D9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF285E6E),
                  ),
                ),
              ),
            ),
            
            const SizedBox(width: 8),
            
            // زر Top Rated Toggle
            GestureDetector(
              onTap: () {
                setState(() {
                  _showOnlyTopRatedRecommended = !_showOnlyTopRatedRecommended;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _showOnlyTopRatedRecommended
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showOnlyTopRatedRecommended
                        ? Colors.orange
                        : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showOnlyTopRatedRecommended
                          ? Icons.star
                          : Icons.star_outline,
                      size: 16,
                      color:
                          _showOnlyTopRatedRecommended ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showOnlyTopRatedRecommended ? "Top Rated" : "All",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showOnlyTopRatedRecommended
                            ? Colors.orange
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // 🔴 عرض رسالة إذا ما في خبراء مطابقين
        if (filteredExperts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EEF3)),
            ),
            child: Column(
              children: [
                const Icon(Icons.search_off, size: 40, color: Colors.grey),
                const SizedBox(height: 10),
                const Text(
                  "No experts found matching your interests yet",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                const Text(
                  "Try editing your interests or check back later",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    _showInterestsSelection();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF62C6D9),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 36),
                  ),
                  child: const Text("Edit Interests"),
                ),
              ],
            ),
          )
        else
          Column(
            children: [
              // فلترة حسب Top Rated إذا شغال
              SizedBox(
                height: MediaQuery.of(context).size.width < 700 ? 220 : 190,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final expert = filteredExperts[index] as Map<String, dynamic>;
                    return _buildRecommendedExpertCard(expert);
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemCount: filteredExperts.length,
                ),
              ),
              
              // 🔴 عرض عدد الخبراء المطابقين
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${filteredExperts.length} expert${filteredExperts.length == 1 ? '' : 's'} match your interests",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    if (_showOnlyTopRatedRecommended)
                      Text(
                        "${filteredExperts.where((e) {
                          final dynamic ratingVal = e['ratingAvg'];
                          final double rating = ratingVal is num ? ratingVal.toDouble() : 0.0;
                          return rating >= 4.0;
                        }).length} top-rated experts",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  // 🔴 كارت Recommended مع Book Button
  Widget _buildRecommendedExpertCard(Map<String, dynamic> expert) {
    final name = (expert["name"] ?? "Unknown").toString();
    final specialty = (expert["specialization"] ?? expert["specialty"] ?? "N/A").toString();
    
    // ✅ FIXED: toDouble() بشكل آمن
    final dynamic ratingVal = expert["ratingAvg"] ?? expert["rating"] ?? 0;
    final double rating = ratingVal is num ? ratingVal.toDouble() : 0.0;

    final String profileImageUrl =
        ApiConfig.fixAssetUrl(expert['profileImageUrl'] as String?);
    
    final isMobile = MediaQuery.of(context).size.width < 700;
    final cardWidth = isMobile ? 160 : 140;

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.zero,
      width: cardWidth.toDouble(),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            // صورة الخبير
            Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF62C6D9),
                    Color(0xFF3BA8B7),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage:
                    profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl.isEmpty
                    ? const Icon(Icons.person,
                        size: 28, color: Color(0xFF62C6D9))
                    : null,
              ),
            ),
            const SizedBox(height: 10),

            // الاسم
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

            // التخصص
            Text(
              specialty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),

            const Spacer(),

            // التقييم + Book
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 15, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF62C6D9),
                        Color(0xFF3BA8B7),
                      ],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
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
                      // BOOK Button - يحتاج تسجيل دخول
                      _requireLogin(() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExpertDetailPage(expert: expert),
                          ),
                        );
                      });
                    },
                    child: const Text(
                      "Book",
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
    );

    // ✅ تحسين: استخدم GestureDetector للموبايل و MouseRegion للويب فقط
    if (kIsWeb) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: cardContent,
      );
    } else {
      return GestureDetector(
        onTap: () {
          // عند الضغط على الكرت كله، يفتح صفحة Expert
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpertDetailPage(expert: expert),
            ),
          );
        },
        child: cardContent,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _expertsPageController = PageController(viewportFraction: 0.78);
    _expertsPageController.addListener(() {
      setState(() {
        _expertsPage = _expertsPageController.page ?? 0.0;
      });
    });

    fetchUser().then((_) {
      // ✅ Only logged-in users get interests flow
      if (!isGuest) {
        _checkFirstTimeUser();
      }
    });

    fetchExperts().then((_) {
      if (!isGuest) {
        _loadUserInterests();
      }
    });
  }

  void _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getStringList('user_interests') == null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showInterestsSelection();
        }
      });
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _expertsPageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // دالة للتمرير إلى قسم معين
  void _scrollTo(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  // دالة مساعدة لعناصر الميزات
  Widget _buildFeatureItem(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F7FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF62C6D9)),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // دالة مساعدة لعناصر الاتصال
  Widget _buildContactItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF62C6D9)),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Future<void> fetchUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    if (token.isEmpty) {
      setState(() {
        user = null;
        loading = false;
      });
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
        // token invalid -> guest
        setState(() => user = null);
        debugPrint('Failed to fetch user: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => user = null);
      debugPrint("Error fetching user: $e");
    } finally {
      setState(() => loading = false);
    }
  }

Future<void> fetchExperts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

    final headers = <String, String>{};
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http.get(
      Uri.parse('$baseUrl/api/public/experts'),
      headers: headers.isEmpty ? null : headers,
    );

    debugPrint("Experts API Status: ${res.statusCode}");
    debugPrint("Experts API Response: ${res.body}");

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        experts = (data['experts'] ?? []) as List<dynamic>;
        loadingExperts = false;
      });
      debugPrint("Loaded ${experts.length} experts");
    } else {
      debugPrint("Failed to load experts: ${res.statusCode} ${res.body}");
      setState(() => loadingExperts = false);
    }
  } catch (e) {
    debugPrint("Error loading experts: $e");
    setState(() => loadingExperts = false);
  }
}
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
      // ✅ FIXED: استخدم 'ALL' بدل null
      if (_selectedCategory != 'ALL') {
        params['category'] = _selectedCategory;
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
          _searchResults =
              items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    final String userName = isGuest
        ? "Guest"
        : (user?['name'] ?? user?['email']?.split('@')[0] ?? 'User');

    final Widget mainBody = loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await fetchUser();
              await fetchExperts();
              if (!isGuest) _loadUserInterests();
              if (_hasSearched) await _searchServices();
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 16 : 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ScrollReveal(
                        delay: const Duration(milliseconds: 0),
                        child: Container(
                          key: _homeKey,
                          child: _buildWelcomeBanner(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ✅ قسم About يظهر فقط في Guest Mode
                      if (isGuest)
                        ScrollReveal(
                          delay: const Duration(milliseconds: 100),
                          child: Container(
                            key: _aboutKey,
                            margin: const EdgeInsets.only(top: 40, bottom: 40),
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "About Lost Treasures",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF285E6E),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      "Lost Treasures is a platform that connects skilled experts with people seeking guidance. "
                                      "We help you discover mentors, book 1:1 sessions, and grow with confidence. "
                                      "Whether you're looking for career advice, technical guidance, or creative inspiration, "
                                      "our verified experts are here to help you unlock your potential.",
                                      style: TextStyle(fontSize: 14, height: 1.7, color: Colors.black87),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        _buildFeatureItem(Icons.verified, "Verified Experts"),
                                        const SizedBox(width: 20),
                                        _buildFeatureItem(Icons.schedule, "Flexible Scheduling"),
                                        const SizedBox(width: 20),
                                        _buildFeatureItem(Icons.security, "Secure Booking"),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      ScrollReveal(
                        delay: const Duration(milliseconds: 120),
                        child: _buildSearchAndFilters(),
                      ),
                      const SizedBox(height: 24),

                      if (_hasSearched) ...[
                        ScrollReveal(
                          delay: const Duration(milliseconds: 220),
                          child: _buildSearchResultsSection(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 🔴 🔴 🔴 قسم Recommended مع Book Button
                      if (!isGuest)
                        ScrollReveal(
                          delay: const Duration(milliseconds: 320),
                          child: Card(
                            elevation: 3,
                            shadowColor: Colors.black12,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: _buildRecommendedSection(),
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),

                      ScrollReveal(
                        delay: const Duration(milliseconds: 420),
                        child: _buildExpertsSectionCard(),
                      ),
                      const SizedBox(height: 24),

                      ScrollReveal(
                        delay: const Duration(milliseconds: 520),
                        child: _buildCategoriesSectionCard(),
                      ),

                      // ✅ قسم Contact Us يظهر فقط في Guest Mode
                      if (isGuest)
                        ScrollReveal(
                          delay: const Duration(milliseconds: 600),
                          child: Container(
                            key: _contactKey,
                            margin: const EdgeInsets.only(top: 40, bottom: 40),
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Contact Us",
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF285E6E),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildContactItem(Icons.email, "support@losttreasures.com"),
                                              const SizedBox(height: 12),
                                              _buildContactItem(Icons.phone, "+970 599 000 000"),
                                              const SizedBox(height: 12),
                                              _buildContactItem(Icons.location_on, "Palestine, Nablus"),
                                            ],
                                          ),
                                        ),
                                        if (!isMobile)
                                          Container(
                                            width: 200,
                                            height: 150,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              color: const Color(0xFFF3F7FA),
                                            ),
                                            child: const Icon(Icons.chat, size: 60, color: Color(0xFF62C6D9)),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isMobile ? 60 : 70),
        child: _buildTopBar(userName, isMobile),
      ),
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentColor,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        label: const Text("Chatbot", style: TextStyle(color: Colors.white)),
        onPressed: () {
          _requireLogin(() {
            if (isMobile) {
              // ✅ على الموبايل، افتح كـ Bottom Sheet
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return SafeArea(
                    child: Padding(
                      // ✅ FIXED: padding للكيبورد
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.85,
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: AiAssistantPanel(
                          userName: userName,
                          userId: user?['_id']?.toString() ?? '',
                          onClose: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  );
                },
              );
            } else {
              // ✅ على الويب، استخدم الـ Panel العادي
              setState(() {
                _showAiAssistant = !_showAiAssistant;
              });
            }
          });
        },
      ),

      body: Stack(
        children: [
          mainBody,

          if (_showAiAssistant && !isGuest && !isMobile)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 24, bottom: 90),
                child: SizedBox(
                  width: 420,
                  height: 520,
                  child: AiAssistantPanel(
                    userName: userName,
                    userId: user?['_id']?.toString() ?? '',
                    onClose: () {
                      setState(() {
                        _showAiAssistant = false;
                      });
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================= BOTTOM NAV BAR =========================

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _bottomNavIndex,
      backgroundColor: Colors.white,
      selectedItemColor: accentColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      onTap: (index) {
        setState(() => _bottomNavIndex = index);

        switch (index) {
          case 0:
            // Home button
            if (isGuest) {
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/landing_page', 
                (route) => false
              );
            }
            break;
          case 1:
            _requireLogin(() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerMyBookingsPage()),
              );
            });
            break;
          case 2:
            _requireLogin(() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConversationsPage()),
              );
            });
            break;
          case 3:
            _requireLogin(() {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerExpertsPage()),
              );
            });
            break;
          case 4:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerHelpPage()),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined), label: 'My Bookings'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
        BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined), label: 'My Experts'),
        BottomNavigationBarItem(icon: Icon(Icons.help_outline), label: 'Help'),
      ],
    );
  }

  // ========================= TOP BAR =========================

  PreferredSizeWidget _buildTopBar(String userName, bool isMobile) {
    return isMobile ? _buildMobileTopBar(userName) : _buildDesktopTopBar(userName);
  }

  AppBar _buildMobileTopBar(String userName) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: GestureDetector(
        onTap: _handleHomePress,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [primaryColor, accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/treasure_icon.png',
                  height: 20,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              "Lost Treasures",
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Icon(isGuest ? Icons.login : Icons.person_outline, color: accentColor),
        onPressed: () {
          if (isGuest) {
            Navigator.pushNamed(context, '/login_page');
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
            );
          }
        },
      ),
      actions: [
        if (isGuest) ...[
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/login_page'),
            child: const Text("Login", style: TextStyle(color: accentColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/signup_page'),
            child: const Text("Sign Up", style: TextStyle(color: accentColor)),
          ),
        ] else ...[
          IconButton(
            tooltip: "Notifications",
            icon: const Icon(Icons.notifications_none, color: accentColor),
            onPressed: () {
              _requireLogin(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerNotificationsPage(),
                  ),
                );
              });
            },
          ),
          IconButton(
            tooltip: "Calendar",
            icon: const Icon(Icons.calendar_month_outlined, color: accentColor),
            onPressed: () {
              _requireLogin(() {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerCalendarPage()),
                );
              });
            },
          ),
          // 🔴 زر تسجيل الخروج الجديد
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: accentColor),
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text("Logout", style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await _logoutUser();
              }
            },
          ),
        ],
      ],
    );
  }

  AppBar _buildDesktopTopBar(String userName) {
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
          GestureDetector(
            onTap: _handleHomePress,
            child: Row(
              children: [
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
              ],
            ),
          ),
          const SizedBox(width: 30),
          
          // Navigation buttons - تظهر فقط في Guest Mode
          if (isGuest) ...[
            TextButton(
              onPressed: () => _scrollTo(_homeKey),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
              child: const Text("Home", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => _scrollTo(_aboutKey),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
              child: const Text("About", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () => _scrollTo(_contactKey),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
              child: const Text("Contact", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 30),
          ],
          
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF6FAFD),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFFE0ECF4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: const Row(
                children: [
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
            if (isGuest) ...[
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: accentColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/login_page'),
                child: const Text("Login",
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentColor,
                  side: const BorderSide(color: accentColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/signup_page'),
                child: const Text("Sign Up",
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 18),
            ] else ...[
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Welcome back,",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
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
              
              IconButton(
                tooltip: "Notifications",
                icon: const Icon(Icons.notifications_none, color: accentColor),
                onPressed: () {
                  _requireLogin(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerNotificationsPage(),
                      ),
                    );
                  });
                },
              ),
              IconButton(
                tooltip: "Messages",
                icon: const Icon(Icons.message_outlined, color: accentColor),
                onPressed: () {
                  _requireLogin(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConversationsPage()),
                    );
                  });
                },
              ),
              IconButton(
                tooltip: "Help & Support",
                icon: const Icon(Icons.help_outline, color: accentColor),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerHelpPage()),
                  );
                },
              ),
              IconButton(
                tooltip: "My Calendar",
                icon: const Icon(Icons.calendar_month_outlined, color: accentColor),
                onPressed: () {
                  _requireLogin(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomerCalendarPage()),
                    );
                  });
                },
              ),
              const SizedBox(width: 4),

              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: accentColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  _requireLogin(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomerExpertsPage()),
                    );
                  });
                },
                icon: const Icon(Icons.people_alt_outlined, size: 18),
                label: const Text(
                  "My Experts",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),

              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: accentColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                onPressed: () {
                  _requireLogin(() {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CustomerMyBookingsPage()),
                    );
                  });
                },
                child: const Text(
                  "My Bookings",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),

              // 🔴 زر Profile Menu مع خيار تسجيل الخروج
              PopupMenuButton<String>(
                offset: const Offset(0, 50),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF62C6D9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFE3F6FA),
                        child: Icon(Icons.person,
                            color: accentColor, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        userName,
                        style: const TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 18, color: accentColor),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, size: 20),
                        SizedBox(width: 8),
                        Text("My Profile"),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings_outlined, size: 20),
                        SizedBox(width: 8),
                        Text("Settings"),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        const Icon(Icons.logout, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        const Text("Logout", style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'logout') {
                    await _logoutUser();
                  } else if (value == 'profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CustomerProfilePage()),
                    );
                  } else if (value == 'settings') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Settings page coming soon!"),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 18),
            ],
          ],
        ),
      ],
    );
  }

  // ========================= UI SECTIONS =========================

  Widget _buildWelcomeBanner() {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 700;

    final textColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isGuest
              ? "Explore mentors as a guest.\nLogin to book your sessions."
              : "Find the right mentor.\nBuild your future with confidence.",
          style: const TextStyle(
            fontSize: 26,
            height: 1.3,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Book 1:1 sessions with verified experts in tech, design, business and more.",
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 14),
        if (isGuest)
          Row(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/login_page'),
                child: const Text("Login"),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pushNamed(context, '/signup_page'),
                child: const Text("Sign Up"),
              ),
            ],
          ),
      ],
    );

    final imageWidget = SizedBox(
      width: isMobile ? 120 : 180,
      height: isMobile ? 120 : 180,
      child: Image.asset(
        "assets/images/mentors_hero.png",
        fit: BoxFit.contain,
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 28,
        vertical: isMobile ? 14 : 24,
      ),
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
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                textColumn,
                const SizedBox(height: 16),
                Center(child: imageWidget),
              ],
            )
          : Row(
              children: [
                Expanded(child: textColumn),
                const SizedBox(width: 18),
                imageWidget,
              ],
            ),
    );
  }

  Widget _buildSearchAndFilters() {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 700;

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

            if (isMobile)
              Column(
                children: [
                  TextField(
                    onChanged: (v) => _searchQuery = v,
                    onSubmitted: (_) => _searchServices(),
                    decoration: InputDecoration(
                      hintText:
                          "e.g. UI design review, Node.js help, marketing strategy...",
                      prefixIcon:
                          const Icon(Icons.search, color: primaryColor, size: 22),
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
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                  ),
                ],
              )
            else
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

            if (isMobile)
              Column(
                children: [
                  DropdownButtonFormField<String>(
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
                    // ✅ FIXED: بدون null في items
                    items: [
                      const DropdownMenuItem(
                        value: 'ALL',
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
                      setState(() => _selectedCategory = v ?? 'ALL');
                      if (_hasSearched) _searchServices();
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
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
                ],
              )
            else
              Row(
                children: [
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
                      // ✅ FIXED: بدون null في items
                      items: [
                        const DropdownMenuItem(
                          value: 'ALL',
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
                        setState(() => _selectedCategory = v ?? 'ALL');
                        if (_hasSearched) _searchServices();
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
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
          height: MediaQuery.of(context).size.width < 700 ? 190 : 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _searchResults.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final isMobile = MediaQuery.of(context).size.width < 700;
              final w = MediaQuery.of(context).size.width;
              // ✅ FIXED: clamp للعرض
            final cardWidth =
    isMobile ? (w - 32).clamp(280, 420).toDouble() : 320.0;

              
              return SizedBox(
                width: cardWidth,
                child: _buildServiceSearchCard(_searchResults[index]),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildServiceSearchCard(Map<String, dynamic> service) {
    final title = (service['title'] ?? 'Untitled').toString();
    final category = (service['category'] ?? 'General').toString();
    final price = service['price'] ?? 0;
    final currency = (service['currency'] ?? 'USD').toString();
    
    // ✅ FIXED: toDouble() بشكل آمن
    final dynamic ratingVal = service['ratingAvg'] ?? 0;
    final double rating = ratingVal is num ? ratingVal.toDouble() : 0.0;

    final expert = service['expert'] ?? {};
    final profile = service['expertProfile'] ?? {};
    final expertName =
        (expert['name'] ?? profile['name'] ?? 'Expert').toString();

    final String imageUrl =
        ApiConfig.fixAssetUrl(expert['profileImageUrl'] as String?);

    Widget cardContent = AnimatedContainer(
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
          CircleAvatar(
            radius: 26,
            backgroundColor: primaryColor.withOpacity(0.1),
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child:
                imageUrl.isEmpty ? const Icon(Icons.person, color: primaryColor) : null,
          ),
          const SizedBox(width: 12),
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
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                    Text(
                      "$price $currency",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              minimumSize: const Size(80, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              // ✅ booking requires login
              _requireLogin(() {
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
              });
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
    );

    // ✅ تحسين: استخدم GestureDetector للموبايل و MouseRegion للويب فقط
    if (kIsWeb) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: cardContent,
      );
    } else {
      return GestureDetector(
        onTap: () {
          _requireLogin(() {
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
          });
        },
        child: cardContent,
      );
    }
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
          height: MediaQuery.of(context).size.width < 700 ? 220 : 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final expert = experts[index] as Map<String, dynamic>;
              return _buildExpertCard(expert);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 16),
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
    
    // ✅ FIXED: toDouble() بشكل آمن
    final dynamic ratingVal = expert["ratingAvg"] ?? expert["rating"] ?? 0;
    final double rating = ratingVal is num ? ratingVal.toDouble() : 0.0;

    final String profileImageUrl =
    ApiConfig.fixAssetUrl(expert['profileImageUrl'] as String?);
    
    final isMobile = MediaQuery.of(context).size.width < 700;
    final cardWidth = isMobile ? 160 : 140;

    Widget cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.zero,
      width: cardWidth.toDouble(),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
            // صورة الخبير
            Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF62C6D9),
                    Color(0xFF3BA8B7),
                  ],
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white,
                backgroundImage: profileImageUrl.isNotEmpty ? NetworkImage(profileImageUrl) : null,
                child: profileImageUrl.isEmpty
                    ? const Icon(Icons.person,
                        size: 28, color: Color(0xFF62C6D9))
                    : null,
              ),
            ),
            const SizedBox(height: 10),

            // الاسم
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

            // التخصص
            Text(
              specialty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),

            const Spacer(),

            // التقييم
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 15, color: Colors.amber),
                const SizedBox(width: 3),
                Text(
                  "${rating.toStringAsFixed(1)}/5",
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 🔥 الأزرار الجديدة: View + Book
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر View
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(55, 28),
                        backgroundColor: Colors.white,
                        foregroundColor: accentColor,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // View - بدون تسجيل دخول
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
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // زر Book
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF62C6D9),
                          Color(0xFF3BA8B7),
                        ],
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
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
                        // Book - يحتاج تسجيل دخول
                        _requireLogin(() {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExpertDetailPage(expert: expert),
                            ),
                          );
                        });
                      },
                      child: const Text(
                        "Book",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // ✅ تحسين: استخدم GestureDetector للموبايل و MouseRegion للويب فقط
    if (kIsWeb) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: cardContent,
      );
    } else {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExpertDetailPage(expert: expert),
            ),
          );
        },
        child: cardContent,
      );
    }
  }

  Widget _buildCategorySection() {
    final categories = [
      {"title": "Design", "icon": Icons.palette},
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
            childAspectRatio: 3.8,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];

            Widget categoryCard = AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                boxShadow: [
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
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
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
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.grey,
                    )
                  ],
                ),
              ),
            );

            // ✅ تحسين: استخدم GestureDetector للموبايل و InkWell للويب
            if (kIsWeb) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat["title"] as String;
                      _hasSearched = true;
                    });
                    _searchServices();
                  },
                  child: categoryCard,
                ),
              );
            } else {
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat["title"] as String;
                    _hasSearched = true;
                  });
                  _searchServices();
                },
                child: categoryCard,
              );
            }
          },
        ),
      ],
    );
  }
}

// ========================= ScrollReveal =========================

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