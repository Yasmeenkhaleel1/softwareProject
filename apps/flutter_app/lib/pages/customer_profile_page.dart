import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class CustomerProfilePage extends StatefulWidget {
  const CustomerProfilePage({super.key});

  @override
  _CustomerProfilePageState createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  Map<String, dynamic>? user;
  bool loading = true;
  bool editing = false;
  String? _profileImageUrl;
  final picker = ImagePicker();

  // Controllers
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();

  static const baseUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  // ✅ جلب بيانات المستخدم بناءً على التوكن
  Future<void> fetchUser() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
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
        print('Failed to fetch user: ${res.body}');
      }
    } catch (e) {
      print('Error fetching user: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  // ✅ رفع صورة البروفايل إلى السيرفر (يدعم الويب والموبايل)
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

      // ✅ مباشرة بعد رفع الصورة، نحدّث المستخدم في قاعدة البيانات
      final updateRes = await http.put(
        Uri.parse('$baseUrl/api/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'profilePic': imageUrl}),
      );

      if (updateRes.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Image updated successfully!')),
        );
      } else {
        print('❌ Failed to update user: ${updateRes.body}');
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


  // ✅ تحديث البيانات الشخصية
  Future<void> updateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final body = jsonEncode({
        "name": nameController.text,
        "age": ageController.text,
        "gender": genderController.text,
        "profilePic": _profileImageUrl,
      });

      final response = await http.put(
        Uri.parse('$baseUrl/api/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        await fetchUser();
        setState(() => editing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated successfully!')),
        );
      } else {
        print('Failed: ${response.body}');
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  // ✅ واجهة المستخدم
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile'),
        backgroundColor: const Color(0xFF62C6D9),
        actions: [
          if (!editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => editing = true),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF6FBFC),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text('User not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: editing ? uploadProfileImage : null,
                            child: CircleAvatar(
                              radius: 60,
                              backgroundImage: _profileImageUrl != null
                                  ? NetworkImage(_profileImageUrl!)
                                  : const AssetImage('assets/images/profile_placeholder.png')
                                      as ImageProvider,
                              child: editing
                                  ? const Align(
                                      alignment: Alignment.bottomRight,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Colors.white,
                                        child: Icon(Icons.edit,
                                            color: Colors.blueAccent),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildField('Name', nameController, editing),
                          _buildField('Email',
                              TextEditingController(text: user!['email']), false),
                          _buildField('Age', ageController, editing,
                              keyboardType: TextInputType.number),
                          _buildField('Gender', genderController, editing),
                          _buildField('Role',
                              TextEditingController(text: user!['role']), false),
                          const SizedBox(height: 20),
                          if (editing)
                            ElevatedButton(
                              onPressed: updateProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF62C6D9),
                              ),
                              child: const Text('Save Changes'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  // ✅ عنصر بناء الحقول
  Widget _buildField(String label, TextEditingController controller, bool editable,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: editable,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black87),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          fillColor: editable ? Colors.blue[50] : Colors.grey[200],
          filled: true,
        ),
      ),
    );
  }
}
