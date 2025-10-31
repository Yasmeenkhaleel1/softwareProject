//lib/pages/admin_expert_page
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
    } else {
      debugPrint("❌ Approve failed: ${res.statusCode}");
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
    } else {
      debugPrint("❌ Reject failed: ${res.statusCode}");
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
        style: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
      ),
    );
  }

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
    final imageUrl = profile['profileImageUrl'] ?? "assets/images/experts.png";
    final certificates = List<String>.from(profile['certificates'] ?? []);
    final gallery = List<String>.from(profile['gallery'] ?? []);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text("Expert Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // صورة البروفايل
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundImage: imageUrl.startsWith("http")
                          ? NetworkImage(imageUrl)
                          : const AssetImage('assets/images/experts.png') as ImageProvider,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user['email'] ?? '',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                           displayName,
                           style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),

                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Personal Info Card
            _infoCard(
              "🧍‍♀️ Personal Info",
              [
                _infoRow("Gender", user['gender']),
                _infoRow("Age", user['age'].toString()),
               _infoRow("Verified", (user['isVerified'] == true) ? "Yes" : "No"),
               _infoRow("Approved", (user['isApproved'] == true) ? "Yes" : "No"),

              ],
            ),

            const SizedBox(height: 16),

            // Profile Info Card
            _infoCard(
              "📋 Profile Info",
              [
                _infoRow("Specialization", profile['specialization']),
                _infoRow("Experience", "${profile['experience']} years"),
                _infoRow("Bio", profile['bio']),
                _infoRow("Location", profile['location']),
              ],
            ),

            const SizedBox(height: 16),

            // Certificates
            if (certificates.isNotEmpty)
              _infoCard(
                "📜 Certificates",
                certificates.map((url) => _buildLink(url, url)).toList(),
              ),

            const SizedBox(height: 16),

            // Gallery
            if (gallery.isNotEmpty)
              _infoCard(
                "🖼 Gallery",
                [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: gallery
                        .map((g) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                g,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),

            const SizedBox(height: 30),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text("Approve", style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: _approveExpert,
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text("Reject", style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: _rejectExpert,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            const Divider(thickness: 1, height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text("$title:", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
          Expanded(
              flex: 5,
              child: Text(
                "${value ?? '-'}",
                style: const TextStyle(color: Colors.black54),
              )),
        ],
      ),
    );
  }
}
