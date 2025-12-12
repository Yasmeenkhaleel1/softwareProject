// lib/pages/admin_expert_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminExpertPage extends StatefulWidget {
  final String expertId;
  const AdminExpertPage({super.key, required this.expertId});

  @override
  State<AdminExpertPage> createState() => _AdminExpertPageState();
}

class _AdminExpertPageState extends State<AdminExpertPage> {
  // ✅ دالة ديناميكية للحصول على baseUrl بناءً على المنصة
  String getBaseUrl() {
    if (Platform.isAndroid) {
      // للمحاكي الأندرويد
      return "http://10.0.2.2:5000";
    } else if (Platform.isIOS) {
      // للمحاكي iOS
      return "http://localhost:5000";
    } else {
      // للويب وسطح المكتب
      return "http://localhost:5000";
    }
  }
  
  bool loading = true;
  Map<String, dynamic>? expert;

  @override
  void initState() {
    super.initState();
    _fetchExpertProfile();
  }

  Future<void> _fetchExpertProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final baseUrl = getBaseUrl(); // ✅ استخدام الدالة الديناميكية

      final res = await http.get(
        Uri.parse("$baseUrl/api/admin/experts/${widget.expertId}/profile"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        setState(() {
          expert = jsonDecode(res.body);
          loading = false;
        });
      } else {
        debugPrint("❌ Error ${res.statusCode}: ${res.body}");
        debugPrint("📡 Base URL: $baseUrl");
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching profile: $e");
      debugPrint("🔍 تأكد أن السيرفر يعمل على ${getBaseUrl()}");
      setState(() => loading = false);
    }
  }

  Future<void> _approveExpert() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = getBaseUrl(); // ✅ استخدام الدالة الديناميكية

    final res = await http.patch(
      Uri.parse("$baseUrl/api/admin/experts/${widget.expertId}/approve"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Expert approved successfully")),
      );
      _fetchExpertProfile();
    }
  }

  Future<void> _rejectExpert() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reject Expert"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: "Reason for rejection",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text("Cancel")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Reject"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final baseUrl = getBaseUrl(); // ✅ استخدام الدالة الديناميكية

    final res = await http.patch(
      Uri.parse("$baseUrl/api/admin/experts/${widget.expertId}/reject"),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"reason": reasonController.text}),
    );

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ Expert rejected")),
      );
      _fetchExpertProfile();
    }
  }

  Widget _buildLink(String url, String label) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF347C8B),
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  // ======================
  // BUILD (RESPONSIVE)
  // ======================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF62C6D9))),
      );
    }

    if (expert == null || expert!['profile'] == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                "Expert not found",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Expert ID: ${widget.expertId}",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchExpertProfile,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    return isMobile ? _buildMobileView() : _buildWebView();
  }

  // ======================================================
  // 🔒 WEB VIEW
  // ======================================================
  Widget _buildWebView() {
    final user = expert!['user'] ?? {};
    final profile = expert!['profile'] ?? {};
    final displayName = user['name'] ?? profile['name'] ?? "Unknown Expert";
    final imageUrl = profile['profileImageUrl'] ?? "";
    final certificates = List<String>.from(profile['certificates'] ?? []);
    final gallery = List<String>.from(profile['gallery'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          "Expert Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            _webHeaderCard(displayName, user['email'], imageUrl),
            const SizedBox(height: 22),
            _webInfoCard(
              "Personal Information",
              [
                _webInfoRow("Gender", user['gender']),
                _webInfoRow("Age", user['age'].toString()),
                _webInfoRow("Email Verified", user['isVerified'] == true ? "Yes" : "No"),
                _webInfoRow("Admin Approved", user['isApproved'] == true ? "Yes" : "No"),
              ],
            ),
            const SizedBox(height: 18),
            _webInfoCard(
              "Profile Info",
              [
                _webInfoRow("Specialization", profile['specialization']),
                _webInfoRow("Experience", "${profile['experience']} years"),
                _webInfoRow("Bio", profile['bio']),
                _webInfoRow("Location", profile['location']),
              ],
            ),
            if (certificates.isNotEmpty) ...[
              const SizedBox(height: 18),
              _webInfoCard(
                "Certificates",
                certificates.map((url) => _buildLink(url, url)).toList(),
              ),
            ],
            if (gallery.isNotEmpty) ...[
              const SizedBox(height: 18),
              _webGalleryCard(gallery),
            ],
            const SizedBox(height: 26),
            _webActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _webHeaderCard(String name, String email, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF62C6D9), Color(0xFF347C8B), Color(0xFF244C63)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundImage: (imageUrl.isNotEmpty && imageUrl.startsWith("http"))
                ? NetworkImage(imageUrl)
                : const AssetImage("assets/images/experts.png") as ImageProvider,
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text(email,
                    style: const TextStyle(
                        fontSize: 15, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _webInfoCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF244C63))),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _webInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF244C63))),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value ?? "—",
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webGalleryCard(List<String> gallery) {
    return _webInfoCard(
      "Gallery",
      [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: gallery
              .map(
                (img) => ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
              )
              .toList(),
        )
      ],
    );
  }

  Widget _webActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _approveExpert,
          icon: const Icon(Icons.check_circle, color: Colors.white),
          label: const Text("Approve",
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _rejectExpert,
          icon: const Icon(Icons.cancel, color: Colors.white),
          label: const Text("Reject",
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ],
    );
  }

  // ======================================================
  // 📱 MOBILE VIEW
  // ======================================================
  Widget _buildMobileView() {
    final user = expert!['user'] ?? {};
    final profile = expert!['profile'] ?? {};
    final displayName = user['name'] ?? profile['name'] ?? "Unknown Expert";
    final imageUrl = profile['profileImageUrl'] ?? "";
    final certificates = List<String>.from(profile['certificates'] ?? []);
    final gallery = List<String>.from(profile['gallery'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          "Expert Profile",
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: _mobileHeaderCard(displayName, user['email'], imageUrl),
          ),
          
          // Personal Information
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _mobileSectionCard(
                title: "Personal Information",
                children: [
                  _mobileInfoItem("Gender", user['gender']),
                  _mobileInfoItem("Age", user['age']?.toString()),
                  _mobileInfoItem("Email Verified", 
                    user['isVerified'] == true ? "Yes" : "No"),
                  _mobileInfoItem("Admin Approved", 
                    user['isApproved'] == true ? "Yes" : "No"),
                ],
              ),
            ),
          ),
          
          // Profile Information
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _mobileSectionCard(
                title: "Profile Information",
                children: [
                  _mobileInfoItem("Specialization", profile['specialization']),
                  _mobileInfoItem("Experience", 
                    profile['experience'] != null ? "${profile['experience']} years" : null),
                  _mobileInfoItem("Location", profile['location']),
                  if (profile['bio'] != null && profile['bio'].toString().isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          "Bio",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF244C63),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile['bio'].toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          // Certificates
          if (certificates.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _mobileSectionCard(
                  title: "Certificates",
                  children: certificates.map((url) => 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _buildMobileLink(url),
                    )
                  ).toList(),
                ),
              ),
            ),
          
          // Gallery
          if (gallery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _mobileSectionCard(
                  title: "Gallery",
                  children: [
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: gallery.length,
                        itemBuilder: (context, index) => Padding(
                          padding: EdgeInsets.only(
                            left: index == 0 ? 0 : 8,
                            right: index == gallery.length - 1 ? 0 : 8,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              gallery[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Action Buttons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _mobileActionButtons(),
            ),
          ),
          
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
        ],
      ),
    );
  }

  Widget _mobileHeaderCard(String name, String email, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6EC1E4),
            Color(0xFF2970B8),
            Color(0xFF0F3D67)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: (imageUrl.isNotEmpty && imageUrl.startsWith("http"))
                ? NetworkImage(imageUrl)
                : const AssetImage("assets/images/experts.png") as ImageProvider,
            backgroundColor: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              "Expert Profile",
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF244C63),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _mobileInfoItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$label:",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF244C63),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? "—",
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLink(String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F4F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF62C6D9).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: const Color(0xFF347C8B),
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Certificate ${url.substring(url.length - 8)}",
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF347C8B),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: const Color(0xFF347C8B),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _mobileActionButtons() {
    return Column(
      children: [
        // Approve Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            onPressed: _approveExpert,
            icon: const Icon(Icons.check_circle_outline, size: 22),
            label: const Text(
              "Approve Expert",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // Reject Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFEB5757),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0xFFEB5757), width: 1.5),
              ),
              elevation: 0,
            ),
            onPressed: _rejectExpert,
            icon: const Icon(Icons.close, size: 22),
            label: const Text(
              "Reject Expert",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Status Info
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: const Color(0xFF62C6D9),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Review expert information carefully before approving",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}