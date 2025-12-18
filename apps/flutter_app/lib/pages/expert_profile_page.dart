import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart'; // ✅ أضيفي هذا import

class ExpertProfilePage extends StatefulWidget {
  final Map<String, dynamic>? existingProfile;
  const ExpertProfilePage({super.key, this.existingProfile});

  @override
  State<ExpertProfilePage> createState() => _ExpertProfilePageState();
}

class _ExpertProfilePageState extends State<ExpertProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController specializationController =
      TextEditingController();
  final TextEditingController experienceController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  bool _isSubmitting = false;
  bool _isUploadingCerts = false;
  bool _isUploadingGallery = false;
  bool _isUploadingAvatar = false;

  List<String> _certificateUrls = [];
  List<String> _galleryUrls = [];
  String? _profileImageUrl;

  // ✅ استخدمي ApiConfig مباشرة
  String get baseUrl => ApiConfig.baseUrl;

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingProfile != null) {
      final p = widget.existingProfile!;
      nameController.text = p['name'] ?? '';
      bioController.text = p['bio'] ?? '';
      specializationController.text = p['specialization'] ?? '';
      experienceController.text = p['experience']?.toString() ?? '';
      locationController.text = p['location'] ?? '';
      
      // ✅ أصلحي روابط الصور عند التحميل
      _profileImageUrl = ApiConfig.fixAssetUrl(p['profileImageUrl']);
      _certificateUrls = List<String>.from(p['certificates'] ?? [])
          .map((url) => ApiConfig.fixAssetUrl(url))
          .toList();
      _galleryUrls = List<String>.from(p['gallery'] ?? [])
          .map((url) => ApiConfig.fixAssetUrl(url))
          .toList();
    }
  }

  // ================= UPLOAD CERTIFICATES =================
  Future<void> _pickAndUploadCertificates() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (result == null) return;

    setState(() => _isUploadingCerts = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/upload/certificates"),
      );

      for (final f in result.files) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'certificates',
              f.bytes!,
              filename: f.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'certificates',
              f.path!,
              filename: f.name,
            ),
          );
        }
      }

      final resp = await http.Response.fromStream(await request.send());

      if (resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);
        final files = (decoded['files'] as List)
            .map((e) => e['url'] as String)
            .toList();
        
        // ✅ أصلحي الروابط قبل الإضافة
        final fixedFiles = files.map((url) => ApiConfig.fixAssetUrl(url)).toList();
        
        setState(() => _certificateUrls.addAll(fixedFiles));
      }
    } finally {
      setState(() => _isUploadingCerts = false);
    }
  }

  // ================= UPLOAD GALLERY =================
  Future<void> _pickAndUploadGallery() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null) return;

    setState(() => _isUploadingGallery = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/upload/gallery"),
      );

      for (final f in result.files) {
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'gallery',
              f.bytes!,
              filename: f.name,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'gallery',
              f.path!,
              filename: f.name,
            ),
          );
        }
      }

      final resp = await http.Response.fromStream(await request.send());

      if (resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);
        final files = (decoded['files'] as List)
            .map((e) => e['url'] as String)
            .toList();
        
        // ✅ أصلحي الروابط قبل الإضافة
        final fixedFiles = files.map((url) => ApiConfig.fixAssetUrl(url)).toList();
        
        setState(() => _galleryUrls.addAll(fixedFiles));
      }
    } finally {
      setState(() => _isUploadingGallery = false);
    }
  }

  // ================= UPLOAD PROFILE IMAGE =================
  Future<void> _pickAndUploadProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final file = result.files.first;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse("$baseUrl/api/upload/profile"),
      );

      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'avatar',
            file.bytes!,
            filename: file.name,
          ),
        );
      } else {
        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            file.path!,
            filename: file.name,
          ),
        );
      }

      final resp = await http.Response.fromStream(await request.send());

      if (resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);
        // ✅ أصلحي الرابط قبل حفظه
        final fixedUrl = ApiConfig.fixAssetUrl(decoded['file']['url']);
        setState(() => _profileImageUrl = fixedUrl);
      }
    } finally {
      setState(() => _isUploadingAvatar = false);
    }
  }

  // ================= SUBMIT PROFILE =================
  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final token = await getToken();
      if (token == null) return;

      final payload = {
        "name": nameController.text.trim(),
        "bio": bioController.text.trim(),
        "specialization": specializationController.text.trim(),
        "experience":
            int.tryParse(experienceController.text.trim()) ?? 0,
        "location": locationController.text.trim(),
        "profileImageUrl": _profileImageUrl,
        "certificates": _certificateUrls,
        "gallery": _galleryUrls,
      };

      final resp = await http.post(
        Uri.parse("$baseUrl/api/expertProfiles"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        Navigator.pushReplacementNamed(
            context, '/waiting_approval');
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: Text(
          widget.existingProfile != null
              ? "Edit Expert Profile"
              : "Complete Your Expert Profile",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: isMobile
                ? Column(children: _buildContent(isMobile))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildContent(isMobile),
                  ),
          ),
        ),
      ),
    );
  }

  // ================= REST OF YOUR UI CODE =================
  List<Widget> _buildContent(bool isMobile) {
    return [
      Expanded(
        flex: isMobile ? 0 : 1,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              const Text("Your Professional Information",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E2A38))),
              const SizedBox(height: 20),
              _buildTextField("Full Name", nameController,
                  validator: (v) => v!.isEmpty ? "Full name is required" : null,
                  onChanged: _updatePreview),
              _buildTextField("Short Bio", bioController,
                  validator: (v) => v!.isEmpty ? "Bio is required" : null,
                  maxLines: 3,
                  onChanged: _updatePreview),
              _buildTextField("Specialization", specializationController,
                  validator: (v) =>
                      v!.isEmpty ? "Specialization is required" : null,
                  onChanged: _updatePreview),
              _buildTextField("Years of Experience", experienceController,
                  validator: (v) =>
                      v!.isEmpty ? "Experience is required" : null,
                  keyboard: TextInputType.number,
                  onChanged: _updatePreview),
              _buildTextField("Location", locationController,
                  validator: (v) =>
                      v!.isEmpty ? "Location is required" : null,
                  onChanged: _updatePreview),
              const SizedBox(height: 25),

              // === Certificates ===
              const Text("Certificates (PDF or Images)",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed:
                    _isUploadingCerts ? null : _pickAndUploadCertificates,
                icon: const Icon(Icons.upload_file, color: Colors.white),
                label: Text(
                    _isUploadingCerts ? "Uploading..." : "Add Certificates",
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62C6D9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              if (_certificateUrls.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _certificateUrls.map((url) {
                    return Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async =>
                                await launchUrl(Uri.parse(url)),
                            child: Text("• $url",
                                style: const TextStyle(
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete,
                              color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() => _certificateUrls.remove(url));
                          },
                        ),
                      ],
                    );
                  }).toList(),
                ),
              const SizedBox(height: 25),

              // === Gallery ===
              const Text("Gallery Images (Photos of your work)",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _isUploadingGallery ? null : _pickAndUploadGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white),
                label: Text(
                    _isUploadingGallery ? "Uploading..." : "Add Gallery Images",
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF62C6D9),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              if (_galleryUrls.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _galleryUrls.map((url) {
                    return Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 80, 
                            height: 80, 
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            icon: const Icon(Icons.cancel,
                                color: Colors.red, size: 20),
                            onPressed: () {
                              setState(() => _galleryUrls.remove(url));
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              const SizedBox(height: 30),

              Center(
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF62C6D9),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.existingProfile != null
                              ? "Update Profile"
                              : "Save & Continue",
                          style: const TextStyle(
                              fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 40),
      Expanded(
        flex: isMobile ? 0 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 80,
              backgroundImage: _profileImageUrl == null || _profileImageUrl!.isEmpty
                  ? const AssetImage('assets/images/profile_placeholder.png')
                      as ImageProvider
                  : NetworkImage(_profileImageUrl!),
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 10),
            const Text("Upload your profile picture"),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isUploadingAvatar ? null : _pickAndUploadProfileImage,
              icon: const Icon(Icons.upload, color: Colors.white),
              label: Text(
                  _isUploadingAvatar ? "Uploading..." : "Upload Image",
                  style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF62C6D9),
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 30),
            const Text("Preview of Your Profile Card",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2A38))),
            const SizedBox(height: 15),
            _buildLivePreviewCard(),
          ],
        ),
      ),
    ];
  }

  Widget _buildLivePreviewCard() {
    final name = nameController.text.trim();
    final spec = specializationController.text.trim();
    final exp = experienceController.text.trim();
    final bio = bioController.text.trim();

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.25), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name.isEmpty ? "Your Name" : name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFF1E2A38),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            spec.isEmpty
                ? "Your Specialization"
                : "$spec${exp.isNotEmpty ? " | $exp years exp" : ""}",
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Text(
            bio.isEmpty ? "Your short bio will appear here." : bio,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        onChanged: onChanged,
        validator: validator,
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF62C6D9), width: 2),
          ),
        ),
      ),
    );
  }

  void _updatePreview(String _) => setState(() {});
}