// lib/pages/customer_profile_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

import '../config/api_config.dart';            // ✅ مهم
import 'customer_dashboard_page.dart';
import 'change_password_page.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  _CustomerProfilePageState createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? user;
  bool loading = true;
  bool editing = false;
  String? _profileImageUrl; // ⬅ رابط معدَّل للويب + الموبايل
  final picker = ImagePicker();
  List<Map<String, dynamic>> bookingHistory = [];

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();

  // 🎨 ألوان البراند
  static const Color primaryColor = Color(0xFF62C6D9);
  static const Color accentColor = Color(0xFF285E6E);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    super.dispose();
  }

  // ============================
  // 🔹 تحميل معلومات المستخدم
  // ============================
  Future<void> fetchUser() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) {
        setState(() => loading = false);
        return;
      }

      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/customers/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        final rawPic = data['user']?['profilePic'] as String?;
        final fixedPic = ApiConfig.fixAssetUrl(rawPic); // ✅ هنا السر

        if (!mounted) return;
        setState(() {
          user = data['user'];
          nameController.text = user?['name'] ?? '';
          ageController.text = user?['age']?.toString() ?? '';
          genderController.text = user?['gender'] ?? '';
          _profileImageUrl = fixedPic; // ✅ نخزن النسخة المعدّلة
        });
      } else {
        debugPrint('❌ Failed to fetch user: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  // ==================================
  // 🔹 رفع صورة بروفايل جديدة
  // ==================================
  Future<void> uploadProfileImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/upload/customer');

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
        final rawUrl = data['file']['url'] as String?;
        final fixedUrl = ApiConfig.fixAssetUrl(rawUrl); // ✅ للتشغيل على كل المنصات

        if (!mounted) return;
        setState(() {
          _profileImageUrl = fixedUrl;
        });

        // 🔁 نرسل للباك إند الرابط كما هو (rawUrl) عشان يبقى ثابت
        final updateRes = await http.patch(
          Uri.parse('${ApiConfig.baseUrl}/api/customers/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'profilePic': rawUrl}),
        );

        if (updateRes.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Profile picture updated successfully!'),
            ),
          );
          await fetchUser(); // نعيد التحميل للتأكد من التزامن
        } else {
          debugPrint('❌ Failed to update profile pic: ${updateRes.body}');
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Upload failed: $respStr')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    }
  }

  // ============================
  // 🔹 تحديث بيانات البروفايل
  // ============================
  Future<void> updateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final res = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/customers/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': nameController.text.trim(),
          'age': ageController.text.trim(),
          'gender': genderController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated successfully')),
        );
        await fetchUser();
        setState(() => editing = false);
      } else {
        debugPrint('❌ Failed to update profile: ${res.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Update failed: ${res.body}')),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error updating profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    }
  }

  // ============================
  // 🔹 الـ UI
  // ============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FB),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ===== Header & Avatar =====
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, Color(0xFFB3E6F2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: _buildHeaderContent(context),
                  ),
                ),

                // ===== Tabs =====
                Container(
                  color: const Color(0xFFF3F7FB),
                  child: _buildTabBar(),
                ),

                // ===== Tab Views =====
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF6FBFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(26),
                        topRight: Radius.circular(26),
                      ),
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(),
                  
                        _buildSettingsTab(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          // Top bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.home_rounded, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerHomePage(),
                    ),
                  );
                },
              ),
              const Text(
                "My Profile",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              IconButton(
                icon: Icon(
                  editing ? Icons.close_rounded : Icons.edit_rounded,
                  color: Colors.white,
                ),
                onPressed: () => setState(() => editing = !editing),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Avatar + name + email
          Stack(
            alignment: Alignment.center,
            children: [
              // خلفية دائرية خفيفة (SaaS شكل ناعم)
              Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              GestureDetector(
                onTap: uploadProfileImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.white,
                      backgroundImage: (_profileImageUrl != null &&
                              _profileImageUrl!.isNotEmpty)
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage(
                              'assets/images/profile_placeholder.png',
                            ) as ImageProvider,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Text(
            user?['name'] ?? "Customer",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            user?['email'] ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: primaryColor,
      unselectedLabelColor: Colors.grey,
      indicatorColor: primaryColor,
      indicatorWeight: 3,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      tabs: const [
        Tab(icon: Icon(Icons.info_outline_rounded), text: "Info"),
       
        Tab(icon: Icon(Icons.settings_rounded), text: "Settings"),
      ],
    );
  }

  // ============================
  // 🔹 تبويب المعلومات
  // ============================
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Personal Information",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
              child: Column(
                children: [
                  _buildField('Name', nameController, editing),
                  _buildField('Age', ageController, editing,
                      keyboardType: TextInputType.number),
                  _buildField('Gender', genderController, editing),
                  if (editing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 10),
                      child: ElevatedButton.icon(
                        onPressed: updateProfile,
                        icon: const Icon(Icons.save_rounded,
                            color: Colors.white),
                        label: const Text(
                          "Save Changes",
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================
  // 🔹 تبويب التاريخ
  // ============================
  Widget _buildBookingHistoryTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: bookingHistory.isEmpty
          ? const Center(
              child: Text(
                "No booking history yet.",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            )
          : ListView.builder(
              itemCount: bookingHistory.length,
              itemBuilder: (context, index) {
                final booking = bookingHistory[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: primaryColor,
                      child: Icon(Icons.calendar_today,
                          color: Colors.white, size: 18),
                    ),
                    title:
                        Text(booking['expertName'] ?? 'Unknown Expert'),
                    subtitle: Text(booking['date'] ?? 'No Date'),
                  ),
                );
              },
            ),
    );
  }

  // ============================
  // 🔹 تبويب الإعدادات
  // ============================
Widget _buildSettingsTab(BuildContext context) {
  return ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        leading: const Icon(Icons.image_rounded, color: Colors.blueAccent),
        title: const Text("Change Profile Picture"),
        subtitle: const Text("Upload a new profile photo from your device"),
        onTap: uploadProfileImage,
      ),

      const Divider(),

      // ✅ زر Change Password
      ListTile(
        leading: const Icon(Icons.lock_rounded, color: accentColor),
        title: const Text("Change Password"),
        subtitle: const Text("Update your account password securely"),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
        onTap: () async {
          final changed = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
          );

          // اختياري: لو رجعت true من صفحة تغيير الباسورد
          if (changed == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("✅ Password updated successfully")),
            );
          }
        },
      ),

      const Divider(),

      // مساحة لإعدادات أخرى لاحقاً
    ],
  );
}

  // ============================
  // 🔹 عنصر حقل إدخال موحّد
  // ============================
  Widget _buildField(
    String label,
    TextEditingController controller,
    bool editable, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    IconData icon;
    if (label == 'Name') {
      icon = Icons.person_rounded;
    } else if (label == 'Age') {
      icon = Icons.cake_rounded;
    } else {
      icon = Icons.wc_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        enabled: editable,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor),
          filled: true,
          fillColor: editable ? Colors.white : const Color(0xFFF5F7FA),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
