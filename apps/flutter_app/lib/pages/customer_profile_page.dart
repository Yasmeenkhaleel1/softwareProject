import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loadingUser = true;
  bool editing = false;
  bool uploadingImage = false;

  String? _profileImageUrl;
  final picker = ImagePicker();

  List<dynamic> bookingHistory = [];
  bool loadingBookings = true;

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();

  static const String baseUrl = "http://localhost:5000";

  // COLORS
  static const Color backgroundColor = Color(0xFFEFFAFB);
  static const Color primaryColor = Color(0xFF62C6D9);
  static const Color titleBlue = Color(0xFF007AFF);

  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadUserAndBookings();
  }

  @override
  void dispose() {
    _tab.dispose();
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    super.dispose();
  }

  // ---------------------------- LOAD USER + BOOKINGS ----------------------------
  Future<void> _loadUserAndBookings() async {
    await fetchUser();
    await fetchBookings();
  }

  Future<void> fetchUser() async {
    setState(() => loadingUser = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final res = await http.get(
        Uri.parse("$baseUrl/api/customers/me"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        user = data["user"];

        nameController.text = user?["name"] ?? "";
        ageController.text = user?["age"]?.toString() ?? "";
        genderController.text = user?["gender"] ?? "";
        _profileImageUrl = user?["profilePic"];
      }
    } catch (_) {}

    setState(() => loadingUser = false);
  }

  Future<void> fetchBookings() async {
    if (user == null) return;

    setState(() => loadingBookings = true);

    try {
      final id = user!["_id"];
      final res = await http.get(
        Uri.parse("$baseUrl/api/bookings?customer=$id"),
      );

      if (res.statusCode == 200) {
        bookingHistory = jsonDecode(res.body)["bookings"];
      }
    } catch (_) {}

    setState(() => loadingBookings = false);
  }

  // ---------------------------- UI MAIN ----------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title:
            const Text("My Profile", style: TextStyle(color: Colors.white)),
      ),
      body: loadingUser
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                _buildTabs(),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _infoTab(),
                      _historyTab(),
                      _settingsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ---------------------------- HEADER ----------------------------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, Color(0xFF4EB5C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 38,
                  backgroundImage:
                      _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                  child: _profileImageUrl == null
                      ? const Icon(Icons.person, size: 45, color: primaryColor)
                      : null,
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: uploadProfileImage,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: uploadingImage
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit, size: 15, color: primaryColor),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?["name"] ?? "",
                  style: const TextStyle(
                      fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(user?["email"] ?? "",
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(editing ? Icons.close : Icons.edit, color: Colors.white),
            onPressed: () => setState(() => editing = !editing),
          )
        ],
      ),
    );
  }

  // ---------------------------- TABS ----------------------------
  Widget _buildTabs() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        indicatorColor: primaryColor,
        labelColor: titleBlue,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(icon: Icon(Icons.info), text: "Info"),
          Tab(icon: Icon(Icons.history), text: "History"),
          Tab(icon: Icon(Icons.settings), text: "Settings"),
        ],
      ),
    );
  }

  // ---------------------------- INFO TAB ----------------------------
  Widget _infoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            _input("Full Name", nameController, Icons.person),
            const SizedBox(height: 12),

            _input("Age", ageController, Icons.cake,
                type: TextInputType.number),
            const SizedBox(height: 12),

            _input("Gender", genderController, Icons.wc),
            const SizedBox(height: 25),

            if (editing)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: updateProfile,
                  label: const Text("Save Changes",
                      style: TextStyle(color: Colors.white)),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _input(
      String label, TextEditingController c, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: c,
      enabled: editing,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  // ---------------------------- UPDATE PROFILE ----------------------------
  Future<void> updateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      final res = await http.patch(
        Uri.parse("$baseUrl/api/customers/me"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "name": nameController.text,
          "age": ageController.text,
          "gender": genderController.text,
        }),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Profile updated")));
        fetchUser();
      }
    } catch (e) {}
  }

  // ---------------------------- UPLOAD PROFILE PIC ----------------------------
  Future<void> uploadProfileImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => uploadingImage = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final req = http.MultipartRequest(
          "POST", Uri.parse("$baseUrl/api/upload/customer"));
      req.headers["Authorization"] = "Bearer $token";

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        req.files.add(
          http.MultipartFile.fromBytes("file", bytes,
              filename: picked.name),
        );
      } else {
        req.files.add(
            await http.MultipartFile.fromPath("file", picked.path));
      }

      final resp = await req.send();
      final body = await resp.stream.bytesToString();

      if (resp.statusCode == 201) {
        final imageUrl = jsonDecode(body)["file"]["url"];

        await http.patch(
          Uri.parse("$baseUrl/api/customers/me"),
          headers: {
            "Authorization": "Bearer $token",
            "Content-Type": "application/json"
          },
          body: jsonEncode({"profilePic": imageUrl}),
        );
        setState(() => _profileImageUrl = "$imageUrl?v=${DateTime.now().millisecondsSinceEpoch}");

        fetchUser();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated!")),
        );
      }
    } catch (e) {}

    setState(() => uploadingImage = false);
  }

  // ---------------------------- HISTORY TAB ----------------------------
  Widget _historyTab() {
    if (loadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bookingHistory.isEmpty) {
      return const Center(child: Text("No bookings yet."));
    }

    final now = DateTime.now();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: bookingHistory.length,
      itemBuilder: (context, i) {
        final b = bookingHistory[i];
        final expert = b["expert"];
        final snapshot = b["serviceSnapshot"] ?? {};
        final title = snapshot["title"] ?? "Service";

        DateTime? start;
        try {
          start = DateTime.parse(b["startAt"]);
        } catch (_) {}

        bool isPast =
            start != null && start.isBefore(now);

        final meetingUrl = b["meetingUrl"];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EXPERT
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.teal,
                    backgroundImage: expert?["profileImageUrl"] != null
                        ? NetworkImage(expert["profileImageUrl"])
                        : null,
                    child: expert?["profileImageUrl"] == null
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      expert?["name"] ?? "Unknown expert",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  )
                ],
              ),

              const SizedBox(height: 10),

              Text(title,
                  style: const TextStyle(
                      color: Colors.black87, fontSize: 14)),

              if (start != null)
                Text(
                  "$start",
                  style: const TextStyle(color: Colors.black54),
                ),

              const SizedBox(height: 14),

              if (!isPast)
                meetingUrl != null
                    ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor),
                        onPressed: () =>
                            launchUrl(Uri.parse(meetingUrl)),
                        child: const Text("Join Session",
                            style: TextStyle(color: Colors.white)),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () => _startSession(b),
                        child: const Text("Start Session",
                            style: TextStyle(color: Colors.white)),
                      ),

              if (isPast)
                Row(
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    final filled = (b["customerRating"] ?? 0) >= star;
                    return GestureDetector(
                      onTap: () => _submitRating(b, star),
                      child: Icon(
                        filled ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 28,
                      ),
                    );
                  }),
                )
            ],
          ),
        );
      },
    );
  }

  Future<void> _startSession(Map<String, dynamic> b) async {
    try {
      final id = b["_id"];
      final res = await http.post(
        Uri.parse("$baseUrl/api/bookings/$id/start-session"),
      );

      final data = jsonDecode(res.body);

      if (data["meetingUrl"] != null) {
        setState(() => b["meetingUrl"] = data["meetingUrl"]);
        launchUrl(Uri.parse(data["meetingUrl"]));
      }
    } catch (_) {}
  }

  Future<void> _submitRating(
      Map<String, dynamic> b, int rating) async {
    try {
      final id = b["_id"];

      final res = await http.post(
        Uri.parse("$baseUrl/api/bookings/$id/rate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"rating": rating}),
      );

      if (res.statusCode == 200) {
        setState(() => b["customerRating"] = rating);
      }
    } catch (_) {}
  }

  // ---------------------------- SETTINGS TAB ----------------------------
  Widget _settingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6)
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: titleBlue),
                title: const Text("Change Profile Picture"),
                trailing: const Icon(Icons.chevron_right),
                onTap: uploadProfileImage,
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.refresh, color: titleBlue),
                title: const Text("Refresh Profile"),
                trailing: const Icon(Icons.chevron_right),
                onTap: _loadUserAndBookings,
              ),
              const Divider(height: 1),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("Logout"),
                onTap: _logout,
              ),
            ],
          ),
        )
      ],
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      "/login",
      (route) => false,
    );
  }
}
