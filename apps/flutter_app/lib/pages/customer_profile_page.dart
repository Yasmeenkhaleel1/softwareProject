// lib/pages/customer_profile_page.dart
import 'dart:convert';
import 'dart:ui'; // 👈 للـ BackdropFilter (Glassmorphism)
import 'dart:html' as html; // 👈 لفتح رابط الجلسة في تبويب جديد (للويب فقط)

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'customer_dashboard_page.dart';

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
  String? _profileImageUrl;
  final picker = ImagePicker();

  // الحجزات
  List<dynamic> bookingHistory = [];
  bool loadingBookings = true;

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();

  static const String baseUrl = "http://localhost:5000";
  static const Color primaryColor = Color(0xFF62C6D9);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserAndBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    super.dispose();
  }

  // =========================================================
  // 1) تحميل المستخدم ثم الحجزات
  // =========================================================
  Future<void> _loadUserAndBookings() async {
    await fetchUser();
    await fetchBookingsForCurrentUser();
  }

  Future<void> fetchUser() async {
    setState(() => loadingUser = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$baseUrl/api/customers/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          user = data['user'];
          nameController.text = user?['name'] ?? '';
          ageController.text = user?['age']?.toString() ?? '';
          genderController.text = user?['gender']?.toString() ?? '';
          _profileImageUrl = user?['profilePic'];
        });
      } else {
        debugPrint('❌ Failed to fetch user: ${res.body}');
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching user: $e');
    } finally {
      setState(() => loadingUser = false);
    }
  }

  // =========================================================
  // 2) تحميل الحجزات للـ customer الحالي  GET /api/bookings?customer=<id>
  // =========================================================
  Future<void> fetchBookingsForCurrentUser() async {
    if (user == null || user!['_id'] == null) {
      setState(() => loadingBookings = false);
      return;
    }

    setState(() => loadingBookings = true);

    try {
      final customerId = user!['_id'].toString();
      final uri = Uri.parse('$baseUrl/api/bookings?customer=$customerId');

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          bookingHistory = data['bookings'] ?? [];
        });
      } else {
        debugPrint("❌ Failed to load bookings: ${res.body}");
      }
    } catch (e) {
      debugPrint('⚠️ Error loading bookings: $e');
    } finally {
      setState(() => loadingBookings = false);
    }
  }

  // =========================================================
  // 3) رفع صورة البروفايل
  // =========================================================
  Future<void> uploadProfileImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final uri = Uri.parse('$baseUrl/api/upload/customer');

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: pickedFile.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            pickedFile.path,
            filename: pickedFile.name,
          ),
        );
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final data = jsonDecode(respStr);
        final imageUrl = data['file']['url'] as String;
        setState(() => _profileImageUrl = imageUrl);

        await http.patch(
          Uri.parse('$baseUrl/api/customers/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'profilePic': imageUrl}),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile picture updated successfully!')),
        );
        await fetchUser();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $respStr')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    }
  }

  // =========================================================
  // 4) تحديث بيانات البروفايل
  // =========================================================
  Future<void> updateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.patch(
        Uri.parse('$baseUrl/api/customers/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': nameController.text,
          'age': ageController.text,
          'gender': genderController.text,
        }),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated successfully')),
        );
        await fetchUser();
      } else {
        debugPrint('❌ Failed to update profile: ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Update failed: ${res.body}')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    }
  }

  // =========================================================
  // 5) Join Session (Jitsi)
  // =========================================================
  Future<void> _joinSession(Map<String, dynamic> booking) async {
    final id = booking['_id']?.toString();
    if (id == null) return;

    final existingUrl = booking['meetingUrl']?.toString();
    try {
      String meetingUrl;

      if (existingUrl != null && existingUrl.isNotEmpty) {
        meetingUrl = existingUrl;
      } else {
        final uri = Uri.parse('$baseUrl/api/bookings/$id/start-session');
        final res = await http.post(uri);

        if (res.statusCode != 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Failed to create session: ${res.body}')),
          );
          return;
        }

        final data = jsonDecode(res.body);
        meetingUrl = data['meetingUrl'];

        setState(() {
          booking['meetingUrl'] = meetingUrl;
          booking['status'] = 'IN_PROGRESS';
        });
      }

      if (kIsWeb) {
        html.window.open(meetingUrl, '_blank');
      } else {
        // ممكن تضيفي url_launcher لاحقاً للموبايل
      }
    } catch (e) {
      debugPrint('⚠️ Join session error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error joining session: $e')),
      );
    }
  }

  // =========================================================
  // 6) Rating
  // =========================================================
  Future<void> _showRatingDialog(Map<String, dynamic> booking) async {
    int selected = 5;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Rate your session'),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  final filled = star <= selected;
                  return IconButton(
                    onPressed: () {
                      setLocalState(() => selected = star);
                    },
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _submitRating(booking, selected);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitRating(
      Map<String, dynamic> booking, int rating) async {
    final id = booking['_id']?.toString();
    if (id == null) return;

    try {
      final uri = Uri.parse('$baseUrl/api/bookings/$id/rate');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rating': rating}),
      );

      if (res.statusCode == 200) {
        setState(() {
          booking['customerRating'] = rating;
          booking['status'] = 'COMPLETED';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Rating submitted')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to rate: ${res.body}')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Rate error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error rating: $e')),
      );
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
  gradient: LinearGradient(
    colors: [
      Color.fromARGB(255, 58, 182, 216), // سماوي فاتح راقي
      Color.fromARGB(255, 17, 68, 68), // أبيض–سماوي خفيف
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
),

        child: SafeArea(
          child: loadingUser
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(
                  children: [
                    // ======= HEADER (Glass Card) =======
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: _buildHeaderContent(context),
                    ),

                    // ======= MAIN CONTENT CARD (Tabs + Body) =======
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(26),
                            topRight: Radius.circular(26),
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 0.6,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(26),
                            topRight: Radius.circular(26),
                          ),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Column(
                              children: [
                                _buildTabBar(),
                                const Divider(height: 1, color: Colors.white24),
                                Expanded(
                                  child: TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _buildInfoTab(),
                                      _buildBookingHistoryTab(),
                                      _buildSettingsTab(context),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ================= HEADER =================
  Widget _buildHeaderContent(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.7),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                backgroundImage: _profileImageUrl != null
                    ? NetworkImage(_profileImageUrl!)
                    : const AssetImage('assets/images/profile_placeholder.png')
                        as ImageProvider,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?['name'] ?? "Loading...",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?['email'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_user,
                              size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            "Customer Profile",
                            style: TextStyle(
                                color: Colors.white, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.home_outlined, color: Colors.white),
                    tooltip: "Home",
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerHomePage(),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      editing ? Icons.close : Icons.edit,
                      color: Colors.white,
                    ),
                    tooltip: editing ? "Cancel edit" : "Edit profile",
                    onPressed: () => setState(() => editing = !editing),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TAB BAR =================
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.white70,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
          ),
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 18), text: "Info"),
            Tab(icon: Icon(Icons.history, size: 18), text: "History"),
            Tab(icon: Icon(Icons.settings, size: 18), text: "Settings"),
          ],
        ),
      ),
    );
  }

  // ================= INFO TAB =================
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        children: [
          _buildInfoSection(
            title: "Personal Information",
            children: [
              _buildField('Name', nameController, editing),
              _buildField('Age', ageController, editing,
                  keyboardType: TextInputType.number),
              _buildField('Gender', genderController, editing),
            ],
          ),
          const SizedBox(height: 12),
          if (editing)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: updateProfile,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text(
                  "Save Changes",
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  // ================= HISTORY TAB =================
  Widget _buildBookingHistoryTab() {
    if (loadingBookings) {
      return const Center(child: CircularProgressIndicator());
    }

    if (bookingHistory.isEmpty) {
      return const Center(
        child: Text(
          "No booking history yet.",
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    final now = DateTime.now();

    return RefreshIndicator(
      color: primaryColor,
      onRefresh: () async => fetchBookingsForCurrentUser(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
        itemCount: bookingHistory.length,
        itemBuilder: (context, index) {
          final b = bookingHistory[index] as Map<String, dynamic>;
          final expert = b['expert'] as Map<String, dynamic>?;
          final serviceSnapshot =
              b['serviceSnapshot'] as Map<String, dynamic>? ?? {};
          final title = (serviceSnapshot['title'] ?? 'Session').toString();

          DateTime? start;
          try {
            start = DateTime.parse(b['startAt'].toString());
          } catch (_) {}

          final status = (b['status'] ?? 'PENDING').toString();
          final rating = b['customerRating'];
          final meetingUrl = b['meetingUrl']?.toString();

          final isPast = start != null && start.isBefore(now);
          final isUpcoming = start != null && start.isAfter(now);
          final canRate = isPast && rating == null;

          String subtitle = title;
          if (start != null) {
            final local = start.toLocal();
            subtitle +=
                "\n${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} "
                "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24, width: 0.7),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundImage:
                            (expert?['profileImageUrl'] != null &&
                                    (expert!['profileImageUrl'] as String)
                                        .isNotEmpty)
                                ? NetworkImage(
                                    expert['profileImageUrl'] as String)
                                : null,
                        child: expert == null ||
                                (expert['profileImageUrl'] == null ||
                                    (expert['profileImageUrl'] as String)
                                        .isEmpty)
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              expert?['name']?.toString() ?? 'Unknown expert',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == "COMPLETED"
                                        ? Colors.green.withOpacity(0.2)
                                        : status == "CANCELED"
                                            ? Colors.red.withOpacity(0.2)
                                            : Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: status == "COMPLETED"
                                          ? Colors.green[50]
                                          : status == "CANCELED"
                                              ? Colors.red[50]
                                              : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isUpcoming)
                                  const Text(
                                    "Upcoming",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orangeAccent,
                                    ),
                                  )
                                else if (isPast)
                                  const Text(
                                    "Past session",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                if (isUpcoming || meetingUrl != null)
                                  ElevatedButton.icon(
                                    onPressed: () => _joinSession(b),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.video_call,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Join Session',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                if (canRate)
                                  OutlinedButton.icon(
                                    onPressed: () => _showRatingDialog(b),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: Colors.amber.shade300),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.star_border,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    label: const Text(
                                      'Rate',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else if (rating != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toString(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
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
    );
  }

  // ================= SETTINGS TAB =================
  Widget _buildSettingsTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 0.7),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.white),
                  title: const Text(
                    "Change Profile Picture",
                    style: TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: Colors.white70),
                  onTap: uploadProfileImage,
                ),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= Field Widget =================
  Widget _buildField(
    String label,
    TextEditingController controller,
    bool editable, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        enabled: editable,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(
            label == 'Name'
                ? Icons.person
                : label == 'Age'
                    ? Icons.cake
                    : Icons.wc,
            color: Colors.white,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.4)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.25)),
          ),
        ),
      ),
    );
  }
}
