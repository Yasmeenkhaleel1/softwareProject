import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'expert_profile_page.dart';

class ExpertProfileViewPage extends StatefulWidget {
  const ExpertProfileViewPage({super.key});

  @override
  State<ExpertProfileViewPage> createState() => _ExpertProfileViewPageState();
}

class _ExpertProfileViewPageState extends State<ExpertProfileViewPage> {
  Map<String, dynamic>? profile;
  bool isLoading = true;
  bool hasError = false;

  static const baseUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("No token found");

      final uri = Uri.parse("$baseUrl/api/expertProfiles/me");
      final resp = await http.get(uri, headers: {
        "Authorization": "Bearer $token",
      });

      if (resp.statusCode == 200) {
        setState(() {
          profile = jsonDecode(resp.body)['profile'];
          isLoading = false;
        });
      } else {
        setState(() {
          hasError = true;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError || profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Expert Profile"),
          backgroundColor: const Color(0xFF62C6D9),
        ),
        body: const Center(
          child: Text("Failed to load profile."),
        ),
      );
    }

    final p = profile!;
    final name = p['name'] ?? '';
    final bio = p['bio'] ?? '';
    final spec = p['specialization'] ?? '';
    final exp = p['experience']?.toString() ?? '';
    final location = p['location'] ?? '';
    final profileImage = p['profileImageUrl'];
    final certs = (p['certificates'] ?? []) as List<dynamic>;
    final gallery = (p['gallery'] ?? []) as List<dynamic>;
    final status = p['status'] ?? 'pending';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Expert Profile",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF62C6D9),
        centerTitle: true,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              "Edit",
              style: TextStyle(color: Colors.white),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExpertProfilePage(existingProfile: p),
                ),
              );
              _fetchProfile();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 70,
              backgroundImage: (profileImage != null &&
                      profileImage.toString().isNotEmpty)
                  ? NetworkImage(profileImage)
                  : const AssetImage('assets/images/profile_placeholder.png')
                      as ImageProvider,
            ),
            const SizedBox(height: 12),
            Text(
              name.isEmpty ? "Unknown Expert" : name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              spec.isEmpty ? "No specialization" : spec,
              style: const TextStyle(color: Colors.grey),
            ),
            if (exp.isNotEmpty)
              Text(
                "$exp years experience",
                style: const TextStyle(color: Colors.black54),
              ),
            if (location.isNotEmpty)
              Text(
                location,
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'approved'
                    ? Colors.green[100]
                    : status == 'rejected'
                        ? Colors.red[100]
                        : Colors.orange[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Status: ${status.toUpperCase()}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: status == 'approved'
                      ? Colors.green[800]
                      : status == 'rejected'
                          ? Colors.red[800]
                          : Colors.orange[800],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "About Me",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bio.isEmpty ? "No bio provided." : bio,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Certificates",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (certs.isEmpty)
              const Text(
                "No certificates uploaded.",
                style: TextStyle(color: Colors.black54),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: certs
                    .map(
                      (c) => GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(c);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            "• $c",
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 22),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Gallery",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[900],
                ),
              ),
            ),
            const SizedBox(height: 6),
            if (gallery.isEmpty)
              const Text(
                "No gallery images uploaded.",
                style: TextStyle(color: Colors.black54),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: gallery
                    .map(
                      (g) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          g,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
