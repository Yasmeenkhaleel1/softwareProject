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
import 'chat/conversations_page.dart'; // ✅ صفحة المسجات الجديدة
import 'customer_experts_page.dart'; // 👈 صفحة My Experts اللي عملناها
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
bool _showOnlyTopRated = false; // افتراضياً يعرض الكل
  late PageController _expertsPageController;
  double _expertsPage = 0.0;
bool _showOnlyTopRatedGeneral = false; // فلترة لقسم الخبراء العامين
  static const Color primaryColor = Color(0xFF62C6D9);
  static const Color accentColor = Color(0xFF285E6E);
  static String get baseUrl => ApiConfig.baseUrl;

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

  bool _showAiAssistant = false;

  // 🔻 جديد: اندكس الشريط السفلي
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

  // --- متغيرات الاهتمامات المحلية ---
  List<String> _userInterests = [];
  bool _interestsLoaded = false;

  // --- دالة عرض اختيار الاهتمامات للمستخدمين الجدد (محدثة ومحترفة) ---
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
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 600),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header مع Gradient
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF62C6D9),
                          const Color(0xFF3BA8B7),
                          const Color(0xFF287E8D),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          ),
                          child: const Icon(
                            Icons.interests,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Let's personalize your experience!",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Select at least 3 interests to get personalized expert recommendations",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  // Interests Grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            // Counter
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F9FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE3F2FD)),
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
                                  Text(
                                    selectedInterests.length >= 3 
                                        ? "Great! You're ready to go!" 
                                        : "Select ${3 - selectedInterests.length} more",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: selectedInterests.length >= 3 
                                          ? const Color(0xFF4CAF50) 
                                          : const Color(0xFF285E6E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Interests Grid
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 1.6,
                              ),
                              itemCount: interests.length,
                              itemBuilder: (context, index) {
                                final interest = interests[index];
                                final isSelected = selectedInterests.contains(interest['title']);
                                
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
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
                                              color: (interest['color'] as Color).withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ]
                                        : [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(18),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            selectedInterests.remove(interest['title']);
                                          } else {
                                            selectedInterests.add(interest['title']);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: isSelected 
                                                        ? Colors.white.withOpacity(0.2)
                                                        : (interest['color'] as Color).withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    interest['icon'] as IconData,
                                                    color: isSelected 
                                                        ? Colors.white 
                                                        : interest['color'] as Color,
                                                    size: 22,
                                                  ),
                                                ),
                                                const Spacer(),
                                                if (isSelected)
                                                  Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: const BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.white,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color: Color(0xFF4CAF50),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              interest['title'] as String,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected ? Colors.white : const Color(0xFF333333),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              interest['description'] as String,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isSelected 
                                                    ? Colors.white.withOpacity(0.9) 
                                                    : const Color(0xFF666666),
                                                height: 1.3,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
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
                  
                  // Footer مع الأزرار
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: const Color(0xFF62C6D9).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                            ),
                            onPressed: () {
                              // Skip for now
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Skip for now",
                              style: TextStyle(
                                color: Color(0xFF666666),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedInterests.length >= 3 
                                  ? const Color(0xFF62C6D9) 
                                  : Colors.grey.withOpacity(0.5),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                              shadowColor: selectedInterests.length >= 3 
                                  ? const Color(0xFF62C6D9).withOpacity(0.4) 
                                  : Colors.transparent,
                            ),
                            onPressed: selectedInterests.length >= 3 
                                ? () async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setStringList('user_interests', selectedInterests);
                                    
                                    // تحديث الاهتمامات في الـ State
                                    setState(() {
                                      _userInterests = selectedInterests;
                                      _interestsLoaded = true;
                                    });
                                    
                                    Navigator.pop(context);
                                    
                                    // Show success snackbar
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFF4CAF50),
                                        content: Row(
                                          children: [
                                            const Icon(Icons.check_circle, color: Colors.white),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                "Awesome! ${selectedInterests.length} interests saved. Your recommendations are now personalized!",
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
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (selectedInterests.length >= 3)
                                  const Icon(Icons.rocket_launch, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  selectedInterests.length >= 3 
                                      ? "Get Started!" 
                                      : "Select ${3 - selectedInterests.length} more",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }

  // --- دالة لتحميل الاهتمامات من SharedPreferences ---
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

  // القائمة الكاملة للكلمات المفتاحية
  final commonKeywords = {
    'programming': [
      'code', 'developer', 'software', 'web', 'mobile', 'backend', 'frontend', 
      'flutter', 'full stack', 'fullstack', 'computer engineering', 'it', 
      'software engineer', 'python', 'java', 'javascript', 'node', 'react', 'dart'
    ],
    'design': [
      'ui', 'ux', 'graphic', 'illustrator', 'designer', 'photoshop', 'creative', 
      'branding', 'logo', 'figma', 'canva', 'art'
    ],
    'marketing': [
      'marketing', 'seo', 'ads', 'social media', 'digital marketing', 'content creator',
      'growth', 'sales', 'email marketing', 'copywriting'
    ],
    'consulting': [
      'consulting', 'advisor', 'strategy', 'business', 'management', 'startup',
      'career', 'financial advisor', 'mentor'
    ],
    'education': [
      'teacher', 'tutor', 'school', 'academic', 'instructor', 'teaching',
      'professor', 'training', 'course'
    ],
    'translation': [
      'translator', 'translation', 'english', 'arabic', 'languages', 'writing', 
      'editor', 'proofreading'
    ],
  };

  for (var expert in experts) {
    // جلب الـ ID الفريد بناءً على الموديل (userId أو _id)
    final String expertId = expert['userId']?.toString() ?? expert['_id']?.toString() ?? expert['id']?.toString() ?? '';
    final String specialization = (expert['specialization'] ?? '').toString().toLowerCase().trim();
    final String category = (expert['category'] ?? '').toString().toLowerCase().trim();

    bool isMatch = false;

    for (var interest in _userInterests) {
      final interestLower = interest.toLowerCase().trim();

      // فحص التطابق المباشر
      if (specialization.contains(interestLower) || category.contains(interestLower)) {
        isMatch = true;
        break; 
      }

      // فحص الكلمات المفتاحية
      if (commonKeywords.containsKey(interestLower)) {
        final keywords = commonKeywords[interestLower]!;
        if (keywords.any((keyword) => 
            specialization.contains(keyword) || category.contains(keyword))) {
          isMatch = true;
          break;
        }
      }
    }

    // منع التكرار والإضافة للقائمة
    if (isMatch && !seenExpertIds.contains(expertId) && expertId.isNotEmpty) {
      filteredExperts.add(expert);
      seenExpertIds.add(expertId);
    }
  }

  // تطبيق فلترة الأعلى تقييماً (Rating >= 4.0) والترتيب تنازلياً
  if (_showOnlyTopRated) {
    filteredExperts = filteredExperts.where((e) {
      final double rating = (e['ratingAvg'] is num) ? e['ratingAvg'].toDouble() : 0.0;
      return rating >= 4.0;
    }).toList();

    filteredExperts.sort((a, b) {
      final double ratingA = (a['ratingAvg'] is num) ? a['ratingAvg'].toDouble() : 0.0;
      final double ratingB = (b['ratingAvg'] is num) ? b['ratingAvg'].toDouble() : 0.0;
      return ratingB.compareTo(ratingA); // من الأعلى للأقل
    });
  }

  return filteredExperts;
}


Widget _buildRecommendedExpertsSection() {
    // تحميل الخبراء المفلترين حسب الاهتمامات
    final List<dynamic> filteredExperts = _getFilteredExpertsByInterests();
    
    // إذا المستخدم ما اختار اهتمامات بعد، ما نعرض القسم
    if (!_interestsLoaded || _userInterests.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // إذا ما في خبراء مطابقين، نعرض رسالة
    if (filteredExperts.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recommended for you",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF28527A),
                  ),
                ),
                Row(
                  children: [
                    // زر فلترة الأعلى تقييماً
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showOnlyTopRated = !_showOnlyTopRated;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _showOnlyTopRated ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showOnlyTopRated ? Colors.orange : Colors.grey.shade400,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showOnlyTopRated ? Icons.star : Icons.star_outline,
                              size: 16,
                              color: _showOnlyTopRated ? Colors.orange : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showOnlyTopRated ? "Top Rated" : "All",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _showOnlyTopRated ? Colors.orange : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // أيقونة التعديل الأصلية
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Color(0xFF62C6D9)),
                      onPressed: _showInterestsSelection,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EEF3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.search_off, size: 40, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  "No experts found matching your interests yet",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  "Check back later or browse all experts",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recommended for you",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF28527A),
                ),
              ),
              Row(
                children: [
                  // زر فلترة الأعلى تقييماً
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showOnlyTopRated = !_showOnlyTopRated;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _showOnlyTopRated ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showOnlyTopRated ? Colors.orange : Colors.grey.shade400,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _showOnlyTopRated ? Icons.star : Icons.star_outline,
                            size: 16,
                            color: _showOnlyTopRated ? Colors.orange : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showOnlyTopRated ? "Top Rated" : "All",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _showOnlyTopRated ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // أيقونة التعديل الأصلية
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20, color: Color(0xFF62C6D9)),
                    onPressed: _showInterestsSelection,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // عرض الخبراء المفلترين
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: filteredExperts.map((expert) => SizedBox(
              width: 170, 
              child: _buildRecommendedExpertCard(expert),
            )).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ], 
    );
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
      // افحصي إذا كان المستخدم جديداً أو لم يحدد اهتماماته
      _checkFirstTimeUser(); 
    });
    
    fetchExperts().then((_) {
      // بعد ما الخبراء يتحملوا، نحمل اهتمامات المستخدم
      _loadUserInterests();
    });
  }

  void _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getStringList('user_interests') == null) {
      // تأخير بسيط لضمان تحميل الصفحة أولاً
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
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 700;

    final String userName =
        user?['name'] ?? user?['email']?.split('@')[0] ?? 'User';

    // 👇 نفس الـ body السابق لكن مع padding مناسب للموبايل
    final Widget mainBody = loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              await fetchUser();
              await fetchExperts();
              _loadUserInterests(); // إعادة تحميل الاهتمامات
              if (_hasSearched) await _searchServices();
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 16 : 24,
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

                      // 3) Results - نتائج البحث تظهر أولاً إذا كان هناك بحث
                      if (_hasSearched) ...[
                        ScrollReveal(
                          delay: const Duration(milliseconds: 220),
                          child: _buildSearchResultsSection(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 4) Recommended experts - التوصيات الذكية المحلية
                      ScrollReveal(
                        delay: const Duration(milliseconds: 320),
                        child: _buildRecommendedExpertsSection(),
                      ),

                      // 5) Experts Carousel - قسم الخبراء العام
                      ScrollReveal(
                        delay: const Duration(milliseconds: 420),
                        child: _buildExpertsSectionCard(),
                      ),
                      const SizedBox(height: 24),

                      // 6) Categories - التصنيفات
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
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),

      // ✅ AppBar مختلف للموبايل و للديسكتوب بدون ما نخرب تصميم الويب
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isMobile ? 60 : 70),
        child: _buildTopBar(userName, isMobile),
      ),

      // ✅ شريط سفلي مثل إنستغرام (للموبايل فقط)
      bottomNavigationBar: isMobile ? _buildBottomNavBar() : null,

      // 🟢 زر الشات بوت – يفتح/يغلق الـ Panel
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentColor,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        label: const Text("Chatbot", style: TextStyle(color: Colors.white)),
        onPressed: () {
          setState(() {
            _showAiAssistant = !_showAiAssistant;
          });
        },
      ),

      // 🟢 Stack: الداشبورد + الشات بوت فوقه في نفس الشاشة
      body: Stack(
        children: [
          mainBody,

          if (_showAiAssistant)
            Align(
              alignment:
                  isMobile ? Alignment.bottomCenter : Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.only(
                  right: isMobile ? 12 : 24,
                  left: isMobile ? 12 : 0,
                  bottom: isMobile ? 80 : 90, // عشان ما يغطيه الـ FAB
                ),
                child: SizedBox(
                  width: isMobile ? size.width * 0.95 : 420,
                  height: isMobile ? size.height * 0.65 : 520,
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
            // Home – لا نعمل شيء، أنتِ أصلاً على صفحة الهوم
            break;

          case 1:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerMyBookingsPage(),
              ),
            );
            break;

          case 2:
            // 💬 Messages
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ConversationsPage(),
              ),
            );
            break;

          case 3:
            // 👥 My Experts
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerExpertsPage(),
              ),
            );
            break;

          case 4:
            // ❓ Help & Support
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerHelpPage(),
              ),
            );
            break;
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          label: 'My Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          label: 'Messages',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people_alt_outlined),
          label: 'My Experts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.help_outline),
          label: 'Help',
        ),
      ],
    );
  }

  // ========================= TOP BAR =========================

  PreferredSizeWidget _buildTopBar(String userName, bool isMobile) {
    return isMobile
        ? _buildMobileTopBar(userName)
        : _buildDesktopTopBar(userName);
  }

  AppBar _buildMobileTopBar(String userName) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Row(
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
      leading: IconButton(
        icon: const Icon(Icons.person_outline, color: accentColor),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CustomerProfilePage(),
            ),
          );
        },
      ),
      actions: [
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
          tooltip: "Calendar",
          icon: const Icon(Icons.calendar_month_outlined, color: accentColor),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomerCalendarPage(),
              ),
            );
          },
        ),
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
                children: [
                  const Icon(Icons.search, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  const Text(
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

            // 🔔 Notifications
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

            // 💬 Messages
            IconButton(
              tooltip: "Messages",
              icon: const Icon(Icons.message_outlined, color: accentColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConversationsPage(),
                  ),
                );
              },
            ),

            // ❓ Help & Support
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

            // 📅 My Calendar (icon فقط على الويب)
            IconButton(
              tooltip: "My Calendar",
              icon: const Icon(Icons.calendar_month_outlined, color: accentColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerCalendarPage(),
                  ),
                );
              },
            ),

            const SizedBox(width: 4),

            // 👥 My Experts
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerExpertsPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.people_alt_outlined,
                size: 18,
              ),
              label: const Text(
                "My Experts",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 4),

            // 📚 My Bookings (tab على الويب)
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerMyBookingsPage(),
                  ),
                );
              },
              child: const Text(
                "My Bookings",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 👤 My Profile
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
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 700;

    final textColumn = Column(
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
    );

    final imageWidget = SizedBox(
      width: isMobile ? 160 : 180,
      height: isMobile ? 160 : 180,
      child: Image.asset(
        "assets/images/mentors_hero.png",
        fit: BoxFit.contain,
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 18 : 28,
        vertical: isMobile ? 20 : 24,
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

  Widget _buildRecommendedExpertCard(dynamic expert) {
    final name = expert['name'] ?? 'Expert';
    final specialty = expert['specialization'] ?? 'Specialist';
    final rating = (expert['ratingAvg'] ?? 0).toDouble();
    final bookings = expert['bookingsCount'] ?? 0;

    final imageUrl = ApiConfig.fixAssetUrl(
      expert['profileImageUrl'] as String?,
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpertDetailPage(expert: expert),
          ),
        );
      },
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE6EEF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(0xFFE3F6FA),
              backgroundImage:
                  imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(height: 10),

            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              specialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                // التعديل: لا تظهر عدد الحجوزات إذا كانت صفر
                if (bookings > 0)
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, 
                          size: 14, color: Colors.orange),
                      Text(
                        " $bookings",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔎 Search + Category + Sort
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

            // 🔍 حقل البحث + زر Search (مختلف على الموبايل)
            if (isMobile)
              Column(
                children: [
                  TextField(
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

            // فلاتر الكاتيجوري و الترتيب (تحت بعض على الموبايل)
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
            separatorBuilder: (_, __) => const SizedBox(width: 16),
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

    final String imageUrl =
        ApiConfig.fixAssetUrl(expert['profileImageUrl'] as String?);

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
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
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

  Widget _buildSmartExpertCard(dynamic expert) {
    final name = expert['name'] ?? 'Expert';
    final specialty = expert['specialization'] ?? 'Specialist';
    final rating = (expert['ratingAvg'] ?? 0).toDouble();
    final bookings = expert['bookingsCount'] ?? 0;

    final imageUrl = ApiConfig.fixAssetUrl(
      expert['profileImageUrl'] as String?
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpertDetailPage(expert: expert),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 30)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              specialty,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, size: 14, color: Colors.amber),
                Text(" ${rating.toStringAsFixed(1)}"),
                const SizedBox(width: 8),
                Text("🔥 $bookings"),
              ],
            ),
          ],
        ),
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

  // ========================= EXISTING SECTIONS =========================



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

    // فلترة الخبراء العامين حسب التقييم إذا كان الخيار مفعل
    List<dynamic> filteredGeneralExperts = List.from(experts);
    if (_showOnlyTopRatedGeneral) {
      filteredGeneralExperts = filteredGeneralExperts.where((e) {
        final double rating = (e['ratingAvg'] is num) ? e['ratingAvg'].toDouble() : 0.0;
        return rating >= 4.0;
      }).toList();

      // ترتيب تنازلي حسب التقييم
      filteredGeneralExperts.sort((a, b) {
        final double ratingA = (a['ratingAvg'] is num) ? a['ratingAvg'].toDouble() : 0.0;
        final double ratingB = (b['ratingAvg'] is num) ? b['ratingAvg'].toDouble() : 0.0;
        return ratingB.compareTo(ratingA);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "👨‍🏫 Meet Our Experts",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF285E6E),
              ),
            ),
            // زر فلترة الأعلى تقييماً للخبراء العامين
            GestureDetector(
              onTap: () {
                setState(() {
                  _showOnlyTopRatedGeneral = !_showOnlyTopRatedGeneral;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _showOnlyTopRatedGeneral ? Colors.orange.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showOnlyTopRatedGeneral ? Colors.orange : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showOnlyTopRatedGeneral ? Icons.star : Icons.star_outline,
                      size: 16,
                      color: _showOnlyTopRatedGeneral ? Colors.orange : Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showOnlyTopRatedGeneral ? "Top Rated" : "All",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showOnlyTopRatedGeneral ? Colors.orange : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // إذا لم يكن هناك خبراء بعد التصفية
        if (_showOnlyTopRatedGeneral && filteredGeneralExperts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EEF3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.star_outline, size: 40, color: Colors.grey),
                SizedBox(height: 10),
                Text(
                  "No top-rated experts found",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  "Try viewing all experts instead",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final expert = filteredGeneralExperts[index] as Map<String, dynamic>;
                return _buildExpertCard(expert);
              },
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemCount: filteredGeneralExperts.length,
            ),
          ),
      ],
    );
  }
  Widget _buildExpertCard(Map<String, dynamic> expert) {
    final name = (expert["name"] ?? "Unknown").toString();
    final specialty =
        (expert["specialization"] ?? expert["specialty"] ?? "N/A").toString();
    
    final num rawRating = (expert["ratingAvg"] ?? expert["rating"] ?? 0) as num;
    final double rating = rawRating.toDouble();

    final String profileImageUrl =
        ApiConfig.fixAssetUrl(expert['profileImageUrl'] as String?);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 16),
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),

          // 🔥 ظل تركوازي
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

              // التقييم + View
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star,
                          size: 15, color: Colors.amber),
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

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
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
                ),
              ),
            );
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