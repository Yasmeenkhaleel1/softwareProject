import 'dart:convert';
import 'dart:io';
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
  File? _image;
  final picker = ImagePicker();

  // Controllers for editable fields
  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  Future<void> fetchUser() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('http://localhost:5000/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        user = json.decode(res.body)['user'];
        nameController.text = user!['name'];
        ageController.text = user!['age'].toString();
        genderController.text = user!['gender'];
      } else {
        print('Failed to fetch user');
      }
    } catch (e) {
      print('Error fetching user: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> updateProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final request = http.MultipartRequest(
          'PUT', Uri.parse('http://localhost:5000/api/users/${user!["_id"]}'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['name'] = nameController.text;
      request.fields['age'] = ageController.text;
      request.fields['gender'] = genderController.text;

      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profilePic',
          _image!.path,
        ));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        print('Profile updated');
        fetchUser(); // Refresh data
        setState(() => editing = false);
      } else {
        print('Failed to update profile');
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Customer Profile'),
        backgroundColor: Colors.lightBlue[300],
        actions: [
          if (!editing)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => setState(() => editing = true),
            ),
        ],
      ),
      backgroundColor: Colors.lightBlue[50],
      body: loading
          ? Center(child: CircularProgressIndicator())
          : user == null
              ? Center(child: Text('User not found'))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 30, horizontal: 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: editing ? pickImage : null,
                              child: CircleAvatar(
                                radius: 50,
                                backgroundImage: _image != null
                                    ? FileImage(_image!)
                                    : user!['profilePic'] != null
                                        ? NetworkImage(user!['profilePic'])
                                            as ImageProvider
                                        : AssetImage('assets/default.png'),
                              ),
                            ),
                            SizedBox(height: 20),
                            buildField('Name', nameController, editing),
                            buildField('Email',
                                TextEditingController(text: user!['email']),
                                false),
                            buildField('Age', ageController, editing,
                                keyboardType: TextInputType.number),
                            buildField('Gender', genderController, editing),
                            buildField('Role',
                                TextEditingController(text: user!['role']),
                                false),
                            SizedBox(height: 20),
                            if (editing)
                              ElevatedButton(
                                onPressed: updateProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.lightBlue[300],
                                ),
                                child: Text('Save Changes'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget buildField(String label, TextEditingController controller, bool editable,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextField(
        controller: controller,
        enabled: editable,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.lightBlue[800]),
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
