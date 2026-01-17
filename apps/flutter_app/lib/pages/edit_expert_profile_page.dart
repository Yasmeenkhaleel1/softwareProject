import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart'; // ✅ عدّلي المسار إذا لزم

class EditExpertProfilePage extends StatefulWidget {
  final Map<String, dynamic> draft;
  const EditExpertProfilePage({super.key, required this.draft});

  @override
  State<EditExpertProfilePage> createState() => _EditExpertProfilePageState();
}

class _EditExpertProfilePageState extends State<EditExpertProfilePage> {
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
  bool _isUploadingAvatar = false;

  // ✅ SaaS Colors
  static const Color _brand = Color(0xFF62C6D9);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE7ECF3);
  static const Color _pageBg = Color(0xFFF5F7FB);

  // ✅ Stepper state (UI فقط)
  int _step = 0;

  bool get isMobile => MediaQuery.of(context).size.width < 900;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;

    _name = TextEditingController(text: d['name'] ?? '');
    _bio = TextEditingController(text: d['bio'] ?? '');
    _specialization = TextEditingController(text: d['specialization'] ?? '');
    _experience =
        TextEditingController(text: (d['experience'] ?? '').toString());
    _location = TextEditingController(text: d['location'] ?? '');

    _profileImageUrl = d['profileImageUrl'];
    _certificateUrls = List<String>.from(d['certificates'] ?? []);
    _galleryUrls = List<String>.from(d['gallery'] ?? []);

    // ✅ لتحديث الـ Preview مباشرة (UI فقط)
    _name.addListener(_refreshPreview);
    _bio.addListener(_refreshPreview);
    _specialization.addListener(_refreshPreview);
    _experience.addListener(_refreshPreview);
    _location.addListener(_refreshPreview);
  }

  void _refreshPreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.removeListener(_refreshPreview);
    _bio.removeListener(_refreshPreview);
    _specialization.removeListener(_refreshPreview);
    _experience.removeListener(_refreshPreview);
    _location.removeListener(_refreshPreview);

    _name.dispose();
    _bio.dispose();
    _specialization.dispose();
    _experience.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  Future<void> _showPopup(
    String title,
    String message, {
    bool success = true,
  }) async {
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
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ✅ رفع الملفات (عام) — Web: bytes / Mobile(Emulator): path
  Future<String?> _uploadFile(
      String endpoint, PlatformFile file, String field) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse("${ApiConfig.baseUrl}/api/upload/$endpoint");

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      if (kIsWeb) {
        // ✅ Web
        if (file.bytes == null) return null;
        request.files.add(http.MultipartFile.fromBytes(
          field,
          file.bytes!,
          filename: file.name,
        ));
      } else {
        // ✅ Android Emulator / Mobile
        if (file.path == null) return null;
        request.files.add(await http.MultipartFile.fromPath(
          field,
          file.path!,
          filename: file.name,
        ));
      }

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(resp.body);

      if (resp.statusCode == 201) {
        String? url;
        if (decoded['file'] != null) url = decoded['file']['url'];
        if (url == null &&
            decoded['files'] != null &&
            decoded['files'].isNotEmpty) {
          url = decoded['files'][0]['url'];
        }
        // ✅ إصلاح الرابط حسب المنصة (localhost -> 10.0.2.2 على الإيميوليتر)
        return ApiConfig.fixAssetUrl(url);
      }

      debugPrint("Upload failed: ${resp.statusCode} => ${resp.body}");
      return null;
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  // ✅ رفع صورة البروفايل
  Future<void> _pickAndUploadProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.image,
        withData: kIsWeb, // ✅ للويب فقط
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingAvatar = true);
      final file = result.files.first;

      final url = await _uploadFile("profile", file, "avatar");
      if (url != null && url.isNotEmpty) {
        setState(() => _profileImageUrl = url);
        await _showPopup(
            "Profile Updated", "Profile image uploaded successfully.");
      } else {
        await _showPopup("Error", "Failed to upload profile image.",
            success: false);
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
      withData: kIsWeb, // ✅ للويب فقط
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _saving = true);
    for (final file in result.files) {
      final url = await _uploadFile("certificates", file, "certificates");
      if (url != null && url.isNotEmpty) {
        setState(() => _certificateUrls.add(url));
      }
    }
    setState(() => _saving = false);
  }

  Future<void> _pickGallery() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
      withData: kIsWeb, // ✅ للويب فقط
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _saving = true);
    for (final file in result.files) {
      final url = await _uploadFile("gallery", file, "gallery");
      if (url != null && url.isNotEmpty) {
        setState(() => _galleryUrls.add(url));
      }
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
        Uri.parse("${ApiConfig.baseUrl}/api/expertProfiles/draft/$draftId"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        await _showPopup(
            "Draft Saved", "Your draft has been saved successfully.");
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
        Uri.parse("${ApiConfig.baseUrl}/api/expertProfiles/draft/$draftId/submit"),
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

  // ========================== UI ==========================
  @override
  Widget build(BuildContext context) {
    final appBarBg = isMobile ? Colors.white : _brand;
    final appBarFg = isMobile ? _ink : Colors.white;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: appBarBg,
        elevation: isMobile ? 0.6 : 0,
        iconTheme: IconThemeData(color: appBarFg),
        title: Text(
          "Edit Expert Profile",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: appBarFg,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: !isMobile,
        child: LayoutBuilder(
          builder: (context, c) {
            final maxW = c.maxWidth >= 1400 ? 1180.0 : 1040.0;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 18,
                    vertical: isMobile ? 16 : 18,
                  ),
                  child: Form(
                    key: _formKey,
                    child: isMobile ? _mobileBody() : _webBody(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------- Web layout ----------
  Widget _webBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 360,
          child: Column(
            children: [
              _brandCard(),
              const SizedBox(height: 14),
              _previewCard(showBio: true),
              const SizedBox(height: 14),
              _stepperCard(showLabels: true),
              const SizedBox(height: 14),
              _actionsCard(),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: _stepContent()),
      ],
    );
  }

  // ---------- Mobile layout ----------
  Widget _mobileBody() {
    return Column(
      children: [
        _previewCard(showBio: false),
        const SizedBox(height: 14),
        _stepperCard(showLabels: false),
        const SizedBox(height: 14),
        _stepContent(),
        const SizedBox(height: 14),
        _actionsCard(),
      ],
    );
  }

  // ---------- Step content ----------
  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _sectionCard(
          title: "Step 1 • Personal Information",
          subtitle: "Complete your details clearly to build trust.",
          child: Column(
            children: [
              const SizedBox(height: 8),
              _buildField(_name, "Full Name", Icons.person),
              _buildField(_specialization, "Specialization", Icons.school),
              _buildField(_bio, "Biography", Icons.description, maxLines: 3),
              _buildField(
                _experience,
                "Experience (years)",
                Icons.timeline,
                keyboard: TextInputType.number,
              ),
              _buildField(_location, "Location", Icons.location_on),
            ],
          ),
        );

      case 1:
        return _sectionCard(
          title: "Step 2 • Certificates",
          subtitle: "Upload certificates to increase verification confidence.",
          child: _buildUploadSection(
            "Certificates",
            _pickCertificates,
            _certificateUrls,
          ),
        );

      case 2:
      default:
        return _sectionCard(
          title: "Step 3 • Gallery",
          subtitle: "Show your work with high-quality images.",
          child: _buildUploadSection("Gallery", _pickGallery, _galleryUrls),
        );
    }
  }

  // ========================== Cards ==========================
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: _ink)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 12.5,
                    color: _muted,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _brandCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_brand.withOpacity(0.20), _brand.withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Color(0x1A62C6D9),
              child: Icon(Icons.verified_user_rounded,
                  color: Color(0xFF62C6D9)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Expert Profile",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _ink,
                          fontSize: 15)),
                  SizedBox(height: 3),
                  Text("Complete your profile for approval faster.",
                      style: TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewCard({required bool showBio}) {
    final name = _name.text.trim().isEmpty ? "Your Name" : _name.text.trim();
    final spec = _specialization.text.trim().isEmpty
        ? "Specialization"
        : _specialization.text.trim();
    final exp = _experience.text.trim().isEmpty ? "0" : _experience.text.trim();
    final loc =
        _location.text.trim().isEmpty ? "Location" : _location.text.trim();
    final bio = _bio.text.trim().isEmpty
        ? "Add a short bio to help customers trust you."
        : _bio.text.trim();

    String bioShort(String s) {
      final clean = s.replaceAll('\n', ' ').trim();
      if (clean.length <= 140) return clean;
      return "${clean.substring(0, 140)}…";
    }

    final avatarUrl = ApiConfig.fixAssetUrl(_profileImageUrl);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person,
                          size: 60, color: Color(0xFF94A3B8))
                      : null,
                ),
                Positioned(
                  bottom: 4,
                  right: 6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap:
                        _isUploadingAvatar ? null : _pickAndUploadProfileImage,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _brand,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            color: Colors.black.withOpacity(0.12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: _isUploadingAvatar
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt,
                              color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5,
                  color: _ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              spec,
              style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _miniInfo(Icons.timeline_rounded, "$exp yrs")),
                const SizedBox(width: 10),
                Expanded(child: _miniInfo(Icons.location_on_rounded, loc)),
              ],
            ),
            if (showBio) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  bioShort(bio),
                  style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _brand, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  color: _ink, fontWeight: FontWeight.w800, fontSize: 12.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ========================== Stepper ==========================
  Widget _stepperCard({required bool showLabels}) {
    String titleFor(int i) => i == 0 ? "Info" : (i == 1 ? "Certificates" : "Gallery");

    IconData iconFor(int i) => i == 0
        ? Icons.badge_rounded
        : (i == 1 ? Icons.workspace_premium_rounded : Icons.collections_rounded);

    Widget stepItem(int i) {
      final active = _step == i;
      final done = _step > i;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _step = i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              color: active ? _brand.withOpacity(0.12) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: active ? _brand.withOpacity(0.35) : _border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : iconFor(i),
                  color: done ? Colors.green : (active ? _brand : _muted),
                  size: 18,
                ),
                if (showLabels) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      titleFor(i),
                      style: TextStyle(
                        color: active ? _ink : _muted,
                        fontWeight: active ? FontWeight.w900 : FontWeight.w800,
                        fontSize: 12.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Progress",
                style: TextStyle(
                    color: _ink, fontWeight: FontWeight.w900, fontSize: 14.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                stepItem(0),
                const SizedBox(width: 10),
                stepItem(1),
                const SizedBox(width: 10),
                stepItem(2),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _step == 0 ? null : () => setState(() => _step -= 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text("Back"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _step == 2 ? null : () => setState(() => _step += 1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    label: const Text("Next"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================== Actions ==========================
  Widget _actionsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_saving ? Icons.sync_rounded : Icons.verified_rounded,
                    color: _muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _saving ? "Saving..." : "Ready",
                    style: const TextStyle(
                        color: _muted, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _saveDraft,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("💾 Save Draft",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14.5)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submitForReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brand,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white.withOpacity(0.6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("🚀 Submit",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 14.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================== Fields ==========================
  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboard,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _brand),
            labelText: label,
            labelStyle:
                const TextStyle(color: _muted, fontWeight: FontWeight.w700),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: (v) => (v == null || v.isEmpty) ? "Required field" : null,
        ),
      ),
    );
  }

  // ========================== Upload Section ==========================
  Widget _buildUploadSection(String title, VoidCallback onAdd, List<String> urls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _saving ? null : onAdd,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (urls.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded, color: _muted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "No files yet. Click Add to upload.",
                    style:
                        TextStyle(color: _muted, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: urls.map((url) {
              final fixedUrl = ApiConfig.fixAssetUrl(url);
              final isPdf = fixedUrl.toLowerCase().endsWith(".pdf");

              return Stack(
                children: [
                  GestureDetector(
                    onTap: () async {
                      if (await canLaunchUrl(Uri.parse(fixedUrl))) {
                        await launchUrl(Uri.parse(fixedUrl),
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: isPdf
                          ? const Center(
                              child: Icon(Icons.picture_as_pdf,
                                  color: Colors.redAccent, size: 52),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child:
                                  Image.network(fixedUrl, fit: BoxFit.cover),
                            ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deleteImage(url, urls),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(5),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
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
