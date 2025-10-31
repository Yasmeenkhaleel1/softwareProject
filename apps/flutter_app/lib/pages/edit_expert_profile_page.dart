import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // ✅ لفتح الروابط مباشرة

class EditExpertProfilePage extends StatefulWidget {
  final Map<String, dynamic> draft;
  const EditExpertProfilePage({super.key, required this.draft});

  @override
  State<EditExpertProfilePage> createState() => _EditExpertProfilePageState();
}

class _EditExpertProfilePageState extends State<EditExpertProfilePage> {
  static const baseUrl = "http://localhost:5000";

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _bio;
  late TextEditingController _specialization;
  late TextEditingController _experience;
  late TextEditingController _location;

  String? _profileImageUrl;
  List<String> _certificateUrls = [];
  List<String> _galleryUrls = [];
  bool _saving = false;
  bool _isUploadingAvatar = false; // ✅ متغير حالة رفع الصورة

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _name = TextEditingController(text: d['name'] ?? '');
    _bio = TextEditingController(text: d['bio'] ?? '');
    _specialization = TextEditingController(text: d['specialization'] ?? '');
    _experience = TextEditingController(text: (d['experience'] ?? '').toString());
    _location = TextEditingController(text: d['location'] ?? '');
    _profileImageUrl = d['profileImageUrl'];
    _certificateUrls = List<String>.from(d['certificates'] ?? []);
    _galleryUrls = List<String>.from(d['gallery'] ?? []);
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _showPopup(String title, String message, {bool success = true}) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                size: 60,
                color: success ? Colors.green : Colors.redAccent,
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF62C6D9),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ✅ رفع الملفات (عام)
  Future<String?> _uploadFile(String endpoint, PlatformFile file, String field) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse("$baseUrl/api/upload/$endpoint");

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(field, file.bytes!, filename: file.name));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(resp.body);

      if (resp.statusCode == 201) {
        if (decoded['file'] != null) {
          return decoded['file']['url'];
        } else if (decoded['files'] != null && decoded['files'].isNotEmpty) {
          return decoded['files'][0]['url'];
        }
      }
      debugPrint("Upload failed: ${resp.statusCode} => ${resp.body}");
      return null;
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  // ✅ رفع صورة البروفايل فقط (نفس الطريقة القديمة)
  Future<void> _pickAndUploadProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingAvatar = true);
      final file = result.files.first;
      if (file.bytes == null) return;

      final url = await _uploadFile("profile", file, "avatar");
      if (url != null) {
        setState(() => _profileImageUrl = url);
        await _showPopup("Profile Updated", "Profile image uploaded successfully.");
      } else {
        await _showPopup("Error", "Failed to upload profile image.", success: false);
      }
    } catch (e) {
      await _showPopup("Error", "Unexpected error: $e", success: false);
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _pickCertificates() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _saving = true);
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final url = await _uploadFile("certificates", file, "certificates");
      if (url != null) setState(() => _certificateUrls.add(url));
    }
    setState(() => _saving = false);
  }

  Future<void> _pickGallery() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _saving = true);
    for (final file in result.files) {
      if (file.bytes == null) continue;
      final url = await _uploadFile("gallery", file, "gallery");
      if (url != null) setState(() => _galleryUrls.add(url));
    }
    setState(() => _saving = false);
  }

  void _deleteImage(String url, List<String> list) {
    setState(() => list.remove(url));
  }

  Future<void> _saveDraft() async {
    setState(() => _saving = true);
    try {
      final token = await _getToken();
      final draftId = widget.draft['_id'];

      final payload = {
        "name": _name.text.trim(),
        "bio": _bio.text.trim(),
        "specialization": _specialization.text.trim(),
        "experience": int.tryParse(_experience.text.trim()) ?? 0,
        "location": _location.text.trim(),
        "profileImageUrl": _profileImageUrl,
        "certificates": _certificateUrls,
        "gallery": _galleryUrls,
      };

      final res = await http.put(
        Uri.parse("$baseUrl/api/expertProfiles/draft/$draftId"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        await _showPopup("Draft Saved", "Your draft has been saved successfully.");
      } else {
        await _showPopup("Failed", "Could not save draft.", success: false);
      }
    } catch (e) {
      await _showPopup("Error", "Unexpected error: $e", success: false);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _submitForReview() async {
    if (!_formKey.currentState!.validate()) return;
    await _saveDraft();

    setState(() => _saving = true);
    try {
      final token = await _getToken();
      final draftId = widget.draft['_id'];

      final res = await http.post(
        Uri.parse("$baseUrl/api/expertProfiles/draft/$draftId/submit"),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        await _showPopup("Profile Submitted",
            "Your expert profile has been submitted for review.");
        Navigator.pop(context);
      } else {
        await _showPopup("Failed", "Could not submit profile.", success: false);
      }
    } catch (e) {
      await _showPopup("Error", "Unexpected error: $e", success: false);
    } finally {
      setState(() => _saving = false);
    }
  }

  // ========================== 🧱 UI ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Edit Expert Profile",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE1F0F3), Color(0xFFBBE7F0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ✅ الصورة الشخصية مع زر الكاميرا
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person,
                                  size: 70, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 6,
                          child: GestureDetector(
                            onTap: _isUploadingAvatar
                                ? null
                                : _pickAndUploadProfileImage,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF0ed2f7),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(10),
                              child: _isUploadingAvatar
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Text("Personal Information",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 20),

                    _buildGlassField(_name, "Full Name", Icons.person),
                    _buildGlassField(_specialization, "Specialization", Icons.school),
                    _buildGlassField(_bio, "Biography", Icons.description, maxLines: 3),
                    _buildGlassField(_experience, "Experience (years)", Icons.timeline,
                        keyboard: TextInputType.number),
                    _buildGlassField(_location, "Location", Icons.location_on),

                    const SizedBox(height: 30),
                    _buildUploadSection("Certificates", _pickCertificates, _certificateUrls),
                    const SizedBox(height: 25),
                    _buildUploadSection("Gallery", _pickGallery, _galleryUrls),

                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveDraft,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C6D9),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: const Text("💾 Save Draft",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submitForReview,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C6D9),
                              foregroundColor: Colors.white,
                              disabledForegroundColor:
                                  Colors.white.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            child: const Text("🚀 Submit for Review",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassField(TextEditingController controller, String label, IconData icon,
      {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF0ed2f7)),
            labelText: label,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          validator: (v) => (v == null || v.isEmpty) ? "Required field" : null,
        ),
      ),
    );
  }

  Widget _buildUploadSection(String title, VoidCallback onAdd, List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF62C6D9),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onAdd,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: urls.map((url) {
            final isPdf = url.toLowerCase().endsWith(".pdf");
            return Stack(
              children: [
                GestureDetector(
                  onTap: () async {
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url),
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.grey.shade100,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: isPdf
                        ? const Center(
                            child: Icon(Icons.picture_as_pdf,
                                color: Colors.redAccent, size: 50),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(url, fit: BoxFit.cover),
                          ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _deleteImage(url, urls),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}
