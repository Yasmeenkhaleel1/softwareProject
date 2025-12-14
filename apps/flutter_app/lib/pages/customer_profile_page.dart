//customer_profile_page
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'customer_dashboard_page.dart';
import 'package:flutter/foundation.dart';
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
  String? _profileImageUrl;
  final picker = ImagePicker();
  List<Map<String, dynamic>> bookingHistory = [];

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();

   String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:5000";
    } else {
      return "http://10.0.2.2:5000";
    }
  }
  static const Color primaryColor = Color(0xFF62C6D9);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    fetchUser();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    super.dispose();
  }

  Future<void> fetchUser() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
 
 
     final res = await http.get(
        Uri.parse('$baseUrl/api/customers/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          user = data['user'];
          nameController.text = user?['name'] ?? '';
          ageController.text = user?['age']?.toString() ?? '';
          genderController.text = user?['gender'] ?? '';
          _profileImageUrl = user?['profilePic'];
        });
      } else {
        debugPrint('❌ Failed to fetch user: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error fetching user: $e');
    } finally {
      setState(() => loading = false);
    }
  }


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
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: pickedFile.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          pickedFile.path,
          filename: pickedFile.name,
        ));
      }

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        final data = jsonDecode(respStr);
        final imageUrl = data['file']['url'];
        setState(() => _profileImageUrl = imageUrl);

        final updateRes = await http.patch(
          Uri.parse('$baseUrl/api/customers/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'profilePic': imageUrl}),
        );

        if (updateRes.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Profile picture updated successfully!')),
          );
          fetchUser();
        } else {
          debugPrint('❌ Failed to update profile pic: ${updateRes.body}');
        }
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
      fetchUser(); 
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  height: 250,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, Color(0xFFE8F7FA)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: SafeArea(child: _buildHeaderContent(context)),
                ),
                Container(
                  color: const Color(0xFFF6FBFC),
                  child: _buildTabBar(),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF6FBFC),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(),
                        _buildBookingHistoryTab(),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.home, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomerHomePage()),
                  );
                },
              ),
              const Text(
                "Profile",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: Icon(editing ? Icons.close : Icons.edit, color: Colors.white),
                onPressed: () => setState(() => editing = !editing),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.white,
          backgroundImage: _profileImageUrl != null
              ? NetworkImage(_profileImageUrl!)
              : const AssetImage('assets/images/profile_placeholder.png')
                  as ImageProvider,
        ),
        const SizedBox(height: 10),
        Text(
          user?['name'] ?? "Loading...",
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          user?['email'] ?? '',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: primaryColor,
      unselectedLabelColor: Colors.grey,
      indicatorColor: primaryColor,
      tabs: const [
        Tab(icon: Icon(Icons.info_outline), text: "Info"),
        Tab(icon: Icon(Icons.history), text: "History"),
        Tab(icon: Icon(Icons.settings), text: "Settings"),
      ],
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildField('Name', nameController, editing),
          _buildField('Age', ageController, editing,
              keyboardType: TextInputType.number),
          _buildField('Gender', genderController, editing),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton.icon(
                onPressed: updateProfile,
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text("Save Changes",
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingHistoryTab() {
    return bookingHistory.isEmpty
        ? const Center(child: Text("No booking history yet."))
        : ListView.builder(
            itemCount: bookingHistory.length,
            itemBuilder: (context, index) {
              final booking = bookingHistory[index];
              return ListTile(
                title: Text(booking['expertName'] ?? 'Unknown Expert'),
                subtitle: Text(booking['date'] ?? 'No Date'),
              );
            },
          );
  }

  Widget _buildSettingsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: const Icon(Icons.image, color: Colors.blueAccent),
          title: const Text("Change Profile Picture"),
          onTap: uploadProfileImage,
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool editable,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: editable,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(
            label == 'Name'
                ? Icons.person
                : label == 'Age'
                    ? Icons.cake
                    : Icons.wc,
            color: primaryColor,
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}