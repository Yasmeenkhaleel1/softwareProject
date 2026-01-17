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
  final TextEditingController specializationController = TextEditingController();
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
        final fixedFiles =
            files.map((url) => ApiConfig.fixAssetUrl(url)).toList();

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
        final fixedFiles =
            files.map((url) => ApiConfig.fixAssetUrl(url)).toList();

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
        "experience": int.tryParse(experienceController.text.trim()) ?? 0,
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
        Navigator.pushReplacementNamed(context, '/waiting_approval');
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // ================== Step Indicator (UI-only) ==================
  bool get _infoCompleted {
    return nameController.text.trim().isNotEmpty &&
        bioController.text.trim().isNotEmpty &&
        specializationController.text.trim().isNotEmpty &&
        experienceController.text.trim().isNotEmpty &&
        locationController.text.trim().isNotEmpty;
  }

  bool get _uploadsTouched {
    return (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) ||
        _certificateUrls.isNotEmpty ||
        _galleryUrls.isNotEmpty;
  }

  int get _currentStep {
    // Step 1 active until info is complete
    if (!_infoCompleted) return 1;
    // Step 2 active if info complete but no uploads yet
    if (_infoCompleted && !_uploadsTouched) return 2;
    // Step 3 active when info complete and uploads exist (or user at preview stage)
    return 3;
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF62C6D9);
    const dark = Color(0xFF1E2A38);
    const bg = Color(0xFFF6FBFC);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: primary,
            title: Text(
              widget.existingProfile != null
                  ? "Edit Expert Profile"
                  : "Complete Your Expert Profile",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Scrollbar(
              thumbVisibility: !isMobile,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 28,
                  vertical: isMobile ? 16 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ✅ Step Indicator (NEW)
                        _buildStepIndicator(
                          current: _currentStep,
                          infoDone: _infoCompleted,
                          uploadsDone: _uploadsTouched,
                        ),
                        const SizedBox(height: 14),

                        _buildPageHeader(
                          isMobile: isMobile,
                          title: "Your Professional Profile",
                          subtitle:
                              "Step-by-step completion: fill your info, upload documents & work samples, then review your profile preview.",
                        ),
                        const SizedBox(height: 18),

                        // ===== Responsive Layout =====
                        isMobile
                            ? Column(
                                children: [
                                  _buildAvatarPanel(
                                    primary: primary,
                                    dark: dark,
                                    isMobile: isMobile,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildFormPanel(
                                    primary: primary,
                                    dark: dark,
                                    isMobile: isMobile,
                                  ),
                                  const SizedBox(height: 14),
                                  _buildPreviewPanel(
                                    primary: primary,
                                    dark: dark,
                                    isMobile: isMobile,
                                  ),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 7,
                                    child: _buildFormPanel(
                                      primary: primary,
                                      dark: dark,
                                      isMobile: isMobile,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    flex: 5,
                                    child: Column(
                                      children: [
                                        _buildAvatarPanel(
                                          primary: primary,
                                          dark: dark,
                                          isMobile: isMobile,
                                        ),
                                        const SizedBox(height: 18),
                                        _buildPreviewPanel(
                                          primary: primary,
                                          dark: dark,
                                          isMobile: isMobile,
                                        ),
                                      ],
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
      },
    );
  }

 // ================= Step Indicator UI (FIXED RESPONSIVE) =================
Widget _buildStepIndicator({
  required int current,
  required bool infoDone,
  required bool uploadsDone,
}) {
  const primary = Color(0xFF62C6D9);

  final steps = [
    _StepData(
      title: "Info",
      subtitle: "Basic details",
      icon: Icons.badge_outlined,
      state: infoDone
          ? _StepState.done
          : (current == 1 ? _StepState.active : _StepState.todo),
    ),
    _StepData(
      title: "Uploads",
      subtitle: "Certificates & work",
      icon: Icons.cloud_upload_outlined,
      state: uploadsDone
          ? _StepState.done
          : (current == 2 ? _StepState.active : _StepState.todo),
    ),
    _StepData(
      title: "Preview",
      subtitle: "Review card",
      icon: Icons.preview_outlined,
      state: (current == 3) ? _StepState.active : _StepState.todo,
    ),
  ];

  return LayoutBuilder(
    builder: (context, c) {
      final isNarrow = c.maxWidth < 520; // مهم للموبايل

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: isNarrow
            // ✅ Mobile: Vertical steps (no squishing)
            ? Column(
                children: [
                  _buildStepTileVertical(steps[0]),
                  const SizedBox(height: 10),
                  _buildStepConnectorVertical(
                    top: steps[0].state,
                    bottom: steps[1].state,
                    activeColor: primary,
                  ),
                  const SizedBox(height: 10),
                  _buildStepTileVertical(steps[1]),
                  const SizedBox(height: 10),
                  _buildStepConnectorVertical(
                    top: steps[1].state,
                    bottom: steps[2].state,
                    activeColor: primary,
                  ),
                  const SizedBox(height: 10),
                  _buildStepTileVertical(steps[2]),
                ],
              )
            // ✅ Web/Tablet: Horizontal steps (your original idea)
            : Row(
                children: [
                  Expanded(child: _buildStepTileHorizontal(steps[0])),
                  _buildStepConnectorHorizontal(
                    left: steps[0].state,
                    right: steps[1].state,
                    activeColor: primary,
                  ),
                  Expanded(child: _buildStepTileHorizontal(steps[1])),
                  _buildStepConnectorHorizontal(
                    left: steps[1].state,
                    right: steps[2].state,
                    activeColor: primary,
                  ),
                  Expanded(child: _buildStepTileHorizontal(steps[2])),
                ],
              ),
      );
    },
  );
}

Widget _buildStepConnectorHorizontal({
  required _StepState left,
  required _StepState right,
  required Color activeColor,
}) {
  final isFilled = (left == _StepState.done) ||
      (left == _StepState.active && right != _StepState.todo);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 46, // ✅ ثابت بدل Expanded (عشان ما يضغط العناصر)
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: isFilled
            ? activeColor.withOpacity(0.55)
            : Colors.grey.withOpacity(0.18),
      ),
    ),
  );
}

Widget _buildStepConnectorVertical({
  required _StepState top,
  required _StepState bottom,
  required Color activeColor,
}) {
  final isFilled =
      (top == _StepState.done) || (top == _StepState.active && bottom != _StepState.todo);

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    width: 6,
    height: 22,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      color: isFilled
          ? activeColor.withOpacity(0.55)
          : Colors.grey.withOpacity(0.18),
    ),
  );
}

Widget _buildStepTileHorizontal(_StepData s) {
  const primary = Color(0xFF62C6D9);
  const dark = Color(0xFF1E2A38);

  Color ring;
  Color fill;
  IconData icon;

  switch (s.state) {
    case _StepState.done:
      ring = primary;
      fill = primary.withOpacity(0.12);
      icon = Icons.check;
      break;
    case _StepState.active:
      ring = primary;
      fill = primary.withOpacity(0.12);
      icon = s.icon;
      break;
    case _StepState.todo:
    default:
      ring = Colors.grey.withOpacity(0.25);
      fill = Colors.grey.withOpacity(0.10);
      icon = s.icon;
  }

  return Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ring, width: 1.2),
        ),
        child: Icon(
          icon,
          color: (s.state == _StepState.todo) ? Colors.grey[600] : dark,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: dark,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildStepTileVertical(_StepData s) {
  
  return SizedBox(
    width: double.infinity,
    child: _buildStepTileHorizontal(s),
  );
}


  // ================= Header / Panels =================
  Widget _buildPageHeader({
    required bool isMobile,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF62C6D9).withOpacity(0.16),
            Colors.white.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF62C6D9).withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_user, color: Color(0xFF1E2A38)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E2A38),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 12.5 : 13.5,
                    height: 1.35,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF62C6D9).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: const Color(0xFF1E2A38)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2A38),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPanel({
    required Color primary,
    required Color dark,
    required bool isMobile,
  }) {
    return _panelCard(
      title: "Profile Picture",
      icon: Icons.account_circle_outlined,
      subtitle: "Upload a clear photo to increase trust and profile quality.",
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.withOpacity(0.14)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 42 : 52,
                  backgroundImage: _profileImageUrl == null || _profileImageUrl!.isEmpty
                      ? const AssetImage('assets/images/profile_placeholder.png') as ImageProvider
                      : NetworkImage(_profileImageUrl!),
                  backgroundColor: Colors.grey[100],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Upload your profile image",
                        style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E2A38)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "PNG/JPG recommended • Square image looks best",
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingAvatar ? null : _pickAndUploadProfileImage,
                          icon: const Icon(Icons.upload, color: Colors.white),
                          label: Text(
                            _isUploadingAvatar ? "Uploading..." : "Upload Image",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel({
    required Color primary,
    required Color dark,
    required bool isMobile,
  }) {
    return _panelCard(
      title: "Expert Information",
      icon: Icons.badge_outlined,
      subtitle: "Complete your professional details and upload proof of expertise.",
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              "Full Name",
              nameController,
              validator: (v) => v!.isEmpty ? "Full name is required" : null,
              onChanged: _updatePreview,
              icon: Icons.person_outline,
            ),
            _buildTextField(
              "Short Bio",
              bioController,
              validator: (v) => v!.isEmpty ? "Bio is required" : null,
              maxLines: 3,
              onChanged: _updatePreview,
              icon: Icons.edit_note_outlined,
            ),
            _buildTextField(
              "Specialization",
              specializationController,
              validator: (v) => v!.isEmpty ? "Specialization is required" : null,
              onChanged: _updatePreview,
              icon: Icons.work_outline,
            ),
            _buildTextField(
              "Years of Experience",
              experienceController,
              validator: (v) => v!.isEmpty ? "Experience is required" : null,
              keyboard: TextInputType.number,
              onChanged: _updatePreview,
              icon: Icons.timeline_outlined,
            ),
            _buildTextField(
              "Location",
              locationController,
              validator: (v) => v!.isEmpty ? "Location is required" : null,
              onChanged: _updatePreview,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 14),

            _buildCertificatesSection(primary: primary),
            const SizedBox(height: 16),
            _buildGallerySection(primary: primary, isMobile: isMobile),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.6),
                      )
                    : Text(
                        widget.existingProfile != null ? "Update Profile" : "Save & Continue",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCertificatesSection({required Color primary}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF7FBFC),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Certificates (PDF or Images)",
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E2A38)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isUploadingCerts ? null : _pickAndUploadCertificates,
                icon: const Icon(Icons.upload_file, color: Colors.white, size: 18),
                label: Text(
                  _isUploadingCerts ? "Uploading..." : "Add",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_certificateUrls.isEmpty)
            Text(
              "No certificates uploaded yet.",
              style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _certificateUrls.map((url) {
                final short = url.length > 26 ? "${url.substring(0, 26)}..." : url;
                return InputChip(
                  label: Text(short, overflow: TextOverflow.ellipsis),
                  avatar: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  onPressed: () async => await launchUrl(Uri.parse(url)),
                  onDeleted: () => setState(() => _certificateUrls.remove(url)),
                  deleteIcon: const Icon(Icons.close, size: 18),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildGallerySection({required Color primary, required bool isMobile}) {
    final crossAxisCount = isMobile ? 3 : 4;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFFF7FBFC),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Gallery Images (Photos of your work)",
                  style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E2A38)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _isUploadingGallery ? null : _pickAndUploadGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                label: Text(
                  _isUploadingGallery ? "Uploading..." : "Add",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_galleryUrls.isEmpty)
            Text(
              "No gallery images uploaded yet.",
              style: TextStyle(color: Colors.grey[700], fontSize: 12.5),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _galleryUrls.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, i) {
                final url = _galleryUrls[i];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        url,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.white,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.white,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => setState(() => _galleryUrls.remove(url)),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewPanel({
    required Color primary,
    required Color dark,
    required bool isMobile,
  }) {
    return _panelCard(
      title: "Live Preview",
      icon: Icons.preview_outlined,
      subtitle: "This is how your expert card will appear to customers.",
      child: Column(
        children: [
          _buildLivePreviewCard(),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF7FBFC),
              border: Border.all(color: Colors.grey.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF1E2A38)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Tip: Write a clear bio + upload certificates to improve credibility.",
                    style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivePreviewCard() {
    final name = nameController.text.trim();
    final spec = specializationController.text.trim();
    final exp = experienceController.text.trim();
    final bio = bioController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundImage: _profileImageUrl == null || _profileImageUrl!.isEmpty
                ? const AssetImage('assets/images/profile_placeholder.png') as ImageProvider
                : NetworkImage(_profileImageUrl!),
            backgroundColor: Colors.grey[100],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? "Your Name" : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                    color: Color(0xFF1E2A38),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  spec.isEmpty
                      ? "Your Specialization"
                      : "$spec${exp.isNotEmpty ? " • $exp years exp" : ""}",
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Text(
                  bio.isEmpty ? "Your short bio will appear here." : bio,
                  style: const TextStyle(fontSize: 13.5, height: 1.35, color: Colors.black87),
                ),
              ],
            ),
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
    IconData? icon,
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
          prefixIcon: icon == null ? null : Icon(icon),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.18)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF62C6D9), width: 2),
          ),
        ),
      ),
    );
  }

  void _updatePreview(String _) => setState(() {});
}

// ================= Helper Models (UI-only) =================
enum _StepState { todo, active, done }

class _StepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final _StepState state;

  _StepData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
  });
}
