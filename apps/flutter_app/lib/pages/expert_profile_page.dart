import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const baseUrl = "http://localhost:5000";

  // ✅ قراءة التوكن المحفوظ بعد تسجيل الدخول
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
      _profileImageUrl = p['profileImageUrl'];
      _certificateUrls = List<String>.from(p['certificates'] ?? []);
      _galleryUrls = List<String>.from(p['gallery'] ?? []);
    }
  }

  // ---------- Upload Certificates ----------
  Future<void> _pickAndUploadCertificates() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingCerts = true);
      final uri = Uri.parse("$baseUrl/api/upload/certificates");
      final request = http.MultipartRequest('POST', uri);

      for (final f in result.files) {
        if (f.bytes == null) continue;
        request.files.add(http.MultipartFile.fromBytes(
          'certificates',
          f.bytes!,
          filename: f.name,
        ));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);
        final files =
            (decoded['files'] as List).map((e) => e['url'] as String).toList();
        setState(() => _certificateUrls.addAll(files));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Certificates uploaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingCerts = false);
    }
  }

  // ---------- Upload Gallery ----------
  Future<void> _pickAndUploadGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingGallery = true);
      final uri = Uri.parse("$baseUrl/api/upload/gallery");
      final request = http.MultipartRequest('POST', uri);

      for (final f in result.files) {
        if (f.bytes == null) continue;
        request.files.add(http.MultipartFile.fromBytes(
          'gallery',
          f.bytes!,
          filename: f.name,
        ));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body);
        final files =
            (decoded['files'] as List).map((e) => e['url'] as String).toList();
        setState(() => _galleryUrls.addAll(files));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gallery images uploaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingGallery = false);
    }
  }

  // ---------- Upload Profile Image ----------
  Future<void> _pickAndUploadProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingAvatar = true);
      final uri = Uri.parse("$baseUrl/api/upload/profile");
      final request = http.MultipartRequest('POST', uri);

      final file = result.files.first;
      if (file.bytes == null) return;
      request.files.add(http.MultipartFile.fromBytes(
        'avatar',
        file.bytes!,
        filename: file.name,
      ));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode == 201) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final url =
            (decoded['file'] as Map<String, dynamic>)['url'] as String;
        setState(() => _profileImageUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile image uploaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ---------- Submit ----------
  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final token = await getToken();
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ User not logged in.")),
        );
        return;
      }

      final exp = int.tryParse(experienceController.text.trim()) ?? 0;
      final payload = {
        "name": nameController.text.trim(),
        "bio": bioController.text.trim(),
        "specialization": specializationController.text.trim(),
        "experience": exp,
        "location": locationController.text.trim(),
        "profileImageUrl": _profileImageUrl,
        "certificates": _certificateUrls,
        "gallery": _galleryUrls,
      };

      final headers = {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      };

      final isEditing = widget.existingProfile != null;
      final url = isEditing
          ? "$baseUrl/api/expertProfiles/${widget.existingProfile!['_id']}"
          : "$baseUrl/api/expertProfiles";

      final uri = Uri.parse(url);
      final resp = isEditing
          ? await http.patch(uri, headers: headers, body: jsonEncode(payload))
          : await http.post(uri, headers: headers, body: jsonEncode(payload));

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? "Profile updated successfully."
                : "Profile submitted for admin review."),
            backgroundColor: const Color(0xFF62C6D9),
          ),
        );

        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/waiting_approval');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Error: ${resp.body}"),
              backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Unexpected error: $e"),
            backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------- UI ----------
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

  // ---------- Main Layout ----------
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25, vertical: 12),
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
                            onTap: () async => await launchUrl(Uri.parse(url)),
                            child: Text("• $url",
                                style: const TextStyle(
                                    color: Colors.blueAccent,
                                    decoration: TextDecoration.underline)),
                          ),
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.red, size: 20),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 25, vertical: 12),
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
                          child: Image.network(url,
                              width: 80, height: 80, fit: BoxFit.cover),
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
              backgroundImage: _profileImageUrl == null
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
