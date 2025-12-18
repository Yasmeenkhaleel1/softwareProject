import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ أضيفي هذا

import '../config/api_config.dart'; // ✅ أضيفي هذا

class ViewExpertProfilePage extends StatefulWidget {
  const ViewExpertProfilePage({super.key});

  @override
  State<ViewExpertProfilePage> createState() => _ViewExpertProfilePageState();
}

class _ViewExpertProfilePageState extends State<ViewExpertProfilePage> {
  // ✅ استخدمي ApiConfig مباشرة
  String get baseUrl => ApiConfig.baseUrl;

  Map<String, dynamic>? _approved;
  Map<String, dynamic>? _pending;
  bool _loading = true;
  bool _showApproved = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final res = await http.get(
        Uri.parse("$baseUrl/api/expertProfiles/me"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          // ✅ أصلحي روابط الصور عند التحميل
          _approved = data['approvedProfile'];
          _pending = data['pendingProfile'];
          
          // إصلاح روابط الصور إذا كانت موجودة
          if (_approved != null) {
            _approved = _fixProfileImageUrls(_approved!);
          }
          if (_pending != null) {
            _pending = _fixProfileImageUrls(_pending!);
          }
          
          _loading = false;
        });
      } else {
        _loading = false;
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      _loading = false;
    }
  }

  // ✅ دالة لإصلاح روابط الصور في البروفايل
  Map<String, dynamic> _fixProfileImageUrls(Map<String, dynamic> profile) {
    final fixedProfile = Map<String, dynamic>.from(profile);
    
    // إصلاح صورة البروفايل
    if (profile['profileImageUrl'] != null) {
      fixedProfile['profileImageUrl'] = 
          ApiConfig.fixAssetUrl(profile['profileImageUrl']);
    }
    
    // إصلاح الشهادات
    if (profile['certificates'] != null && profile['certificates'] is List) {
      fixedProfile['certificates'] = (profile['certificates'] as List)
          .map((url) => ApiConfig.fixAssetUrl(url))
          .toList();
    }
    
    // إصلاح المعرض
    if (profile['gallery'] != null && profile['gallery'] is List) {
      fixedProfile['gallery'] = (profile['gallery'] as List)
          .map((url) => ApiConfig.fixAssetUrl(url))
          .toList();
    }
    
    return fixedProfile;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 768;
    final activeProfile = _showApproved ? _approved : _pending;
    final status = _showApproved ? "Approved" : "Pending";

    return Scaffold(
      backgroundColor: const Color(0xFFE8F3F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          "My Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF62C6D9),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ===== SWITCH =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSwitchButton("Approved Profile", true),
                      const SizedBox(width: 12),
                      _buildSwitchButton("Pending Profile", false),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ===== CONTENT =====
                  Expanded(
                    child: activeProfile == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_off,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No $status profile available",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: Container(
                              constraints:
                                  const BoxConstraints(maxWidth: 1100),
                              child: isMobile
                                  ? _buildMobileLayout(
                                      activeProfile, status)
                                  : _buildDesktopLayout(
                                      activeProfile, status),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  // ================= MOBILE LAYOUT =================
  Widget _buildMobileLayout(Map<String, dynamic> p, String status) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildLeftProfile(p, status),
          const SizedBox(height: 20),
          _buildDetailedCard(
            title: "About",
            child: Text(
              p['bio'] ?? "No bio provided",
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          _buildDetailedCard(
            title: "Certificates",
            child: _buildCertList(p),
          ),
          const SizedBox(height: 20),
          _buildDetailedCard(
            title: "Gallery",
            child: _buildGalleryList(p),
          ),
        ],
      ),
    );
  }

  // ================= DESKTOP LAYOUT =================
  Widget _buildDesktopLayout(Map<String, dynamic> p, String status) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildLeftProfile(p, status)),
        const SizedBox(width: 25),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildDetailedCard(
                  title: "About",
                  child: Text(
                    p['bio'] ?? "No bio provided",
                    style: const TextStyle(fontSize: 15, height: 1.6),
                  ),
                ),
                const SizedBox(height: 25),
                _buildDetailedCard(
                  title: "Certificates",
                  child: _buildCertList(p),
                ),
                const SizedBox(height: 25),
                _buildDetailedCard(
                  title: "Gallery",
                  child: _buildGalleryList(p),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ================= SWITCH BUTTON =================
  Widget _buildSwitchButton(String title, bool isApprovedButton) {
    final bool isActive = _showApproved == isApprovedButton;
    return GestureDetector(
      onTap: () => setState(() => _showApproved = isApprovedButton),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF62C6D9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF62C6D9)),
          boxShadow: isActive ? [
            BoxShadow(
              color: const Color(0xFF62C6D9).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ] : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ================= LEFT PROFILE CARD =================
  Widget _buildLeftProfile(Map<String, dynamic> p, String status) {
    final Color badgeColor =
        status == "Approved" ? Colors.green : Colors.orange;
    
    // ✅ تحضير رابط صورة البروفايل
    final String? profileImageUrl = p['profileImageUrl'];
    final String? fixedProfileImageUrl = profileImageUrl != null && profileImageUrl.isNotEmpty
        ? ApiConfig.fixAssetUrl(profileImageUrl)
        : null;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 14)
        ],
      ),
      child: Column(
        children: [
          // ✅ صورة البروفايل مع معالجة أخطاء
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF62C6D9).withOpacity(0.3),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: fixedProfileImageUrl != null && fixedProfileImageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: fixedProfileImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF62C6D9),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFFE8F3F6),
                        child: const Icon(
                          Icons.person,
                          size: 50,
                          color: Color(0xFF62C6D9),
                        ),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE8F3F6),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Color(0xFF62C6D9),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 15),
          Text(
            p['name'] ?? "Unnamed",
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            p['specialization'] ?? "",
            style: TextStyle(
              color: Colors.teal[700], 
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Divider(height: 25),
          _infoIcon(Icons.location_on, p['location'] ?? "Unknown"),
          const SizedBox(height: 8),
          _infoIcon(
              Icons.work, "${p['experience'] ?? '--'} years exp."),
          const SizedBox(height: 20),
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withOpacity(0.3)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: badgeColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= DETAIL CARD =================
  Widget _buildDetailedCard(
      {required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF62C6D9), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  // ================= CERTIFICATES =================
  Widget _buildCertList(Map<String, dynamic> p) {
    final certs = List<String>.from(p['certificates'] ?? []);
    if (certs.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.folder_off,
              size: 50,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            const Text(
              "No certificates uploaded",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: certs.map(_buildCertificateItem).toList(),
    );
  }

  Widget _buildCertificateItem(String url) {
    // ✅ إصلاح رابط الشهادة
    final fixedUrl = ApiConfig.fixAssetUrl(url);
    
    return GestureDetector(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(fixedUrl))) {
          await launchUrl(Uri.parse(fixedUrl));
        }
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              url.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf
                  : Icons.image,
              size: 40,
              color: const Color(0xFF62C6D9),
            ),
            const SizedBox(height: 8),
            Text(
              url.split('/').last,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ================= GALLERY =================
  Widget _buildGalleryList(Map<String, dynamic> p) {
    final gallery = List<String>.from(p['gallery'] ?? []);
    if (gallery.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(
              Icons.photo_library,
              size: 50,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 10),
            const Text(
              "No gallery images",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: gallery.map(_buildGalleryItem).toList(),
    );
  }

  Widget _buildGalleryItem(String url) {
    // ✅ إصلاح رابط المعرض
    final fixedUrl = ApiConfig.fixAssetUrl(url);
    
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: fixedUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[200],
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: const Color(0xFF62C6D9),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: Colors.grey[200],
            child: const Icon(
              Icons.broken_image,
              color: Colors.grey,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}