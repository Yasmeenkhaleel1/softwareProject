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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text("My Profile",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ============ Switch Buttons ============
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
                        ? Center(
                            child: Text(
                              _showApproved
                                  ? "No approved profile yet."
                                  : "No profile pending review.",
                              style: const TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                          )
                        : SingleChildScrollView(
                            child: _buildProfileLayout(activeProfile!, status),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSwitchButton(String title, bool isApprovedButton) {
    final bool isActive = _showApproved == isApprovedButton;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showApproved = isApprovedButton),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF62C6D9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF62C6D9)),
            boxShadow: isActive
                ? [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]
                : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileLayout(Map<String, dynamic> p, String status) {
    final certs = List<String>.from(p['certificates'] ?? []);
    final gallery = List<String>.from(p['gallery'] ?? []);
    final Color badgeColor = status == "Approved" ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ======== Profile Header ========
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
  onTap: () {
    final imageUrl = p['profileImageUrl'];
    if (imageUrl != null && imageUrl.toString().startsWith("http")) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(imageUrl),
              ),
            ),
          ),
        ),
      );
    }
  },
  child: CircleAvatar(
    radius: 50,
    backgroundImage: (p['profileImageUrl'] != null &&
            p['profileImageUrl'].toString().startsWith("http"))
        ? NetworkImage(p['profileImageUrl'])
        : const AssetImage('assets/images/experts.png') as ImageProvider,
  ),
),
const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] ?? "Unnamed Expert",
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    if (p['specialization'] != null)
                      Text(p['specialization'],
                          style: const TextStyle(color: Colors.teal, fontSize: 16)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 15,
                      runSpacing: 5,
                      children: [
                        if (p['location'] != null)
                          _infoIcon(Icons.location_on, p['location']),
                        if (p['experience'] != null)
                          _infoIcon(Icons.work, "${p['experience']} years exp."),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(status,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),

          const SizedBox(height: 25),
          _divider("About"),

          if (p['bio'] != null && p['bio'].toString().isNotEmpty)
            Text(
              p['bio'],
              style: const TextStyle(fontSize: 15, height: 1.6, color: Color(0xFF334155)),
            )
          else
            const Text("No bio provided.",
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),

          const SizedBox(height: 25),
          _divider("Certificates"),

          if (certs.isEmpty)
            const Text("No certificates uploaded.",
                style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: certs.map((url) => _buildCertificateItem(url)).toList(),
            ),

          const SizedBox(height: 25),
          _divider("Gallery"),

          if (gallery.isEmpty)
            const Text("No gallery images.",
                style: TextStyle(color: Colors.grey))
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: gallery.map((url) => _buildGalleryItem(url)).toList(),
            ),
        ],
      ),
    );
  }

  Widget _divider(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Container(
          width: 50,
          height: 3,
          color: const Color(0xFF62C6D9),
          margin: const EdgeInsets.only(bottom: 12),
        ),
      ],
    );
  }

  Widget _infoIcon(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Color(0xFF475569))),
      ],
    );
  }

  Widget _buildCertificateItem(String url) {
  if (url.toLowerCase().endsWith(".pdf")) {
    // 🔹 PDF File
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 40, color: Colors.redAccent),
            SizedBox(height: 8),
            Text("Open PDF",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  } else {
    // 🔹 Image File
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              backgroundColor: Colors.black,
              body: Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image.network(url),
                ),
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
      ),
    );
  }
}

Widget _buildGalleryItem(String url) {
  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            backgroundColor: Colors.black,
            body: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(url),
              ),
            ),
          ),
        ),
      );
    },
    child: Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
      ),
    ),
  );
}


 
}
