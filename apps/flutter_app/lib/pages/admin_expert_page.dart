// lib/pages/admin_expert_page.dart
import 'dart:convert';
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
  static const baseUrl = "http://localhost:5000";
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
        setState(() => loading = false);
      }
    } catch (e) {
      debugPrint("❌ Error fetching profile: $e");
      setState(() => loading = false);
    }
  }

  Future<void> _approveExpert() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';

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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
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

  // ----------------------- UI DESIGN START -----------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF62C6D9))),
      );
    }

    if (expert == null || expert!['profile'] == null) {
      return const Scaffold(body: Center(child: Text("Expert not found")));
    }

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

      // ========================= BODY ===========================
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: [
            _headerCard(displayName, user['email'], imageUrl),

            const SizedBox(height: 22),

            _infoCard(
              "Personal Information",
              [
                _infoRow("Gender", user['gender']),
                _infoRow("Age", user['age'].toString()),
                _infoRow("Email Verified", user['isVerified'] == true ? "Yes" : "No"),
                _infoRow("Admin Approved", user['isApproved'] == true ? "Yes" : "No"),
              ],
            ),

            const SizedBox(height: 18),

            _infoCard(
              "Profile Info",
              [
                _infoRow("Specialization", profile['specialization']),
                _infoRow("Experience", "${profile['experience']} years"),
                _infoRow("Bio", profile['bio']),
                _infoRow("Location", profile['location']),
              ],
            ),

            if (certificates.isNotEmpty) ...[
              const SizedBox(height: 18),
              _infoCard(
                "Certificates",
                certificates.map((url) => _buildLink(url, url)).toList(),
              ),
            ],

            if (gallery.isNotEmpty) ...[
              const SizedBox(height: 18),
              _galleryCard(gallery),
            ],

            const SizedBox(height: 26),

            _actionButtons(),
          ],
        ),
      ),
    );
  }

  // ----------------------- HEADER CARD -----------------------------

  Widget _headerCard(String name, String email, String imageUrl) {
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

  // ----------------------- INFO CARD -----------------------------

  Widget _infoCard(String title, List<Widget> children) {
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

  Widget _infoRow(String label, dynamic value) {
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

  // ----------------------- GALLERY -----------------------------

  Widget _galleryCard(List<String> gallery) {
    return _infoCard(
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

  // ----------------------- ACTION BUTTONS -----------------------------

  Widget _actionButtons() {
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
}
