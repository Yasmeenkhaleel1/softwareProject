import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ViewExpertProfilePage extends StatefulWidget {
  const ViewExpertProfilePage({super.key});

  @override
  State<ViewExpertProfilePage> createState() => _ViewExpertProfilePageState();
}

class _ViewExpertProfilePageState extends State<ViewExpertProfilePage> {
  static const baseUrl = "http://localhost:5000";
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
          _approved = data['approvedProfile'];
          _pending = data['pendingProfile'];
          _loading = false;
        });
      } else {
        debugPrint("Error fetching profile: ${res.statusCode}");
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = _showApproved ? _approved : _pending;
    final status = _showApproved ? "Approved" : "Pending";

    return Scaffold(
      backgroundColor: const Color(0xFFE8F3F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text("My Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSwitchButton("Approved Profile", true),
                      const SizedBox(width: 12),
                      _buildSwitchButton("Pending Profile", false),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: activeProfile == null
                        ? const Center(
                            child: Text(
                              "No data available",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 1100),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT — Profile Card
                                  Expanded(
                                    flex: 3,
                                    child: _buildLeftProfile(activeProfile!, status),
                                  ),
                                  const SizedBox(width: 25),
                                  // RIGHT — Details Cards
                                  Expanded(
                                    flex: 6,
                                    child: SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          _buildDetailedCard(
                                            title: "About",
                                            child: Text(activeProfile['bio'] ?? "No bio provided",
                                                style: const TextStyle(fontSize: 15, height: 1.6)),
                                          ),
                                          const SizedBox(height: 25),
                                          _buildDetailedCard(
                                            title: "Certificates",
                                            child: _buildCertList(activeProfile),
                                          ),
                                          const SizedBox(height: 25),
                                          _buildDetailedCard(
                                            title: "Gallery",
                                            child: _buildGalleryList(activeProfile),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchButton(String title, bool isApprovedButton) {
    final bool isActive = _showApproved == isApprovedButton;
    return GestureDetector(
      onTap: () => setState(() => _showApproved = isApprovedButton),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 22),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF62C6D9) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF62C6D9)),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.teal.withOpacity(.25), blurRadius: 10)]
              : [],
        ),
        child: Text(title,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }

  // LEFT CARD
  Widget _buildLeftProfile(Map<String, dynamic> p, String status) {
    final Color badgeColor = status == "Approved" ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundImage: (p['profileImageUrl'] != null &&
                    p['profileImageUrl'].toString().startsWith("http"))
                ? NetworkImage(p['profileImageUrl'])
                : const AssetImage("assets/images/experts.png") as ImageProvider,
          ),
          const SizedBox(height: 15),
          Text(p['name'] ?? "Unnamed",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(p['specialization'] ?? "",
              style: TextStyle(color: Colors.teal[700], fontSize: 14)),
          const Divider(height: 25),
          _infoIcon(Icons.location_on, p['location'] ?? "Unknown"),
          const SizedBox(height: 8),
          _infoIcon(Icons.work, "${p['experience'] ?? '--'} years exp."),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            decoration: BoxDecoration(
                color: badgeColor.withOpacity(.16),
                borderRadius: BorderRadius.circular(8)),
            child: Text(status,
                style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          )
        ],
      ),
    );
  }

  // DETAIL CARD
  Widget _buildDetailedCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child
          ]),
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(children: [
      Icon(icon, color: Colors.grey[700], size: 18),
      const SizedBox(width: 4),
      Text(text)
    ]);
  }

  Widget _buildCertList(Map<String, dynamic> p) {
    final certs = List<String>.from(p['certificates'] ?? []);
    if (certs.isEmpty) {
      return const Text("No certificates uploaded.",
          style: TextStyle(color: Colors.grey));
    }
    return Wrap(
        spacing: 10,
        children: certs.map((url) => _buildCertificateItem(url)).toList());
  }

  Widget _buildGalleryList(Map<String, dynamic> p) {
    final gallery = List<String>.from(p['gallery'] ?? []);
    if (gallery.isEmpty) {
      return const Text("No gallery images.",
          style: TextStyle(color: Colors.grey));
    }
    return Wrap(
        spacing: 10,
        children: gallery.map((url) => _buildGalleryItem(url)).toList());
  }

  Widget _buildCertificateItem(String url) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.picture_as_pdf,
          size: 40, color: Colors.redAccent),
    );
  }

  Widget _buildGalleryItem(String url) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image:
              DecorationImage(fit: BoxFit.cover, image: NetworkImage(url))),
    );
  }
}
