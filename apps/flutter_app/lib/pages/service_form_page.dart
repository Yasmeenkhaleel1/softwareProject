// lib/pages/service_form_page.dart
// ✅ Web + Mobile + SaaS UI (No logic changes)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class ServiceFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const ServiceFormPage({super.key, this.existing});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  static final String baseUrl = ApiConfig.baseUrl;

  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController();
  final _price = TextEditingController();
  final _currency = TextEditingController(text: "USD");
  final _duration = TextEditingController(text: "60");
  final _tags = TextEditingController();
  final _description = TextEditingController();
  final List<TextEditingController> _imageCtrls = [TextEditingController()];

  String? _selectedCategory;
  bool _saving = false;

  final List<String> _categories = const [
    "Design",
    "Programming",
    "Consulting",
    "Marketing",
    "Education",
    "Translation",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _title.text = s['title'] ?? '';
      _selectedCategory = s['category'];
      _price.text = (s['price'] ?? '').toString();
      _currency.text = s['currency'] ?? 'USD';
      _duration.text = (s['durationMinutes'] ?? 60).toString();
      _description.text = s['description'] ?? '';
      _tags.text = (s['tags'] as List?)?.join(', ') ?? '';
      final imgs = (s['images'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (imgs.isNotEmpty) {
        _imageCtrls.clear();
        _imageCtrls.addAll(imgs.map((u) => TextEditingController(text: u)));
      }
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _currency.dispose();
    _duration.dispose();
    _tags.dispose();
    _description.dispose();
    for (final c in _imageCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

  // ====================== SAME LOGIC: Upload ======================
  Future<void> _pickAndUploadImage(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      final fileBytes = result.files.single.bytes;
      final fileName = result.files.single.name;
      final token = await _token();

      final uri = Uri.parse("$baseUrl/api/upload/gallery");
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token';

      if (fileBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'gallery',
            fileBytes,
            filename: fileName,
          ),
        );
      } else if (result.files.single.path != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'gallery',
            result.files.single.path!,
          ),
        );
      }

      final streamedResponse = await request.send();
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        final imageUrl = data['files']?[0]?['url'] ?? '';
        if (imageUrl.isNotEmpty) {
          setState(() => _imageCtrls[index].text = imageUrl);
          _successMsg("✅ Image uploaded successfully");
        }
      } else {
        _errorMsg("Upload failed: ${res.body}");
      }
    } catch (e) {
      _errorMsg("Error uploading image: $e");
    }
  }

  void _successMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ====================== SAME LOGIC: Save ======================
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final t = await _token();

    final body = {
      "title": _title.text.trim(),
      "category": _selectedCategory?.trim() ?? '',
      "description": _description.text.trim(),
      "price": double.tryParse(_price.text) ?? 0,
      "currency": _currency.text.trim(),
      "durationMinutes": int.tryParse(_duration.text) ?? 60,
      "tags": _tags.text
          .split(",")
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList(),
      "images": _imageCtrls
          .map((c) => c.text.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    http.Response res;
    if (widget.existing == null) {
      res = await http.post(
        Uri.parse("$baseUrl/api/services"),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } else {
      final id = widget.existing!['_id'];
      res = await http.put(
        Uri.parse("$baseUrl/api/services/$id"),
        headers: {
          'Authorization': 'Bearer $t',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    }

    setState(() => _saving = false);
    if (res.statusCode == 200 || res.statusCode == 201) {
      _successMsg("Saved successfully");
      Navigator.pop(context, true);
    } else {
      _errorMsg("Error: ${res.body}");
    }
  }

  // ====================== UI Helpers (SaaS look) ======================
  static const _primary = Color(0xFF62C6D9);
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _card = Color(0xFFFFFFFF);

  InputDecoration _dec(String label, {String? hint, Widget? prefix, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionTitle({required IconData icon, required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primary.withOpacity(0.18)),
          ),
          child: Icon(icon, color: const Color(0xFF2F8CA5), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: _muted, height: 1.3)),
            ],
          ),
        )
      ],
    );
  }

  Widget _tf(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    bool required = false,
    String? hint,
    Widget? prefix,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      decoration: _dec(label, hint: hint, prefix: prefix, suffix: suffix),
    );
  }

  Widget _ta(String label, TextEditingController c, {bool required = false, String? hint}) {
    return TextFormField(
      controller: c,
      minLines: 5,
      maxLines: 10,
      validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      decoration: _dec(label, hint: hint, prefix: const Icon(Icons.subject_outlined)),
    );
  }

  Widget _categoryDropdown() {
    return DropdownButtonFormField<String?>(
      value: _selectedCategory,
      items: _categories
          .map((c) => DropdownMenuItem<String?>(value: c, child: Text(c)))
          .toList(),
      onChanged: (val) => setState(() => _selectedCategory = val),
      decoration: _dec("Category", prefix: const Icon(Icons.category_outlined)),
      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

  // ====================== Images Block ======================
  Widget _imagesBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_imageCtrls.length, (index) {
          final c = _imageCtrls[index];
          final fixedUrl = ApiConfig.fixAssetUrl(c.text.trim());
          final hasUrl = fixedUrl.isNotEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.04),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 78,
                    height: 78,
                    color: const Color(0xFFEAF4F8),
                    child: hasUrl
                        ? Image.network(
                            fixedUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                              size: 28,
                            ),
                          )
                        : const Icon(Icons.image_outlined, color: Color(0xFF7C8DA3), size: 28),
                  ),
                ),
                const SizedBox(width: 12),

                // URL field
                Expanded(
                  child: _tf(
                    "Image URL",
                    c,
                    hint: "Paste image link or upload from device",
                    prefix: const Icon(Icons.link_outlined),
                  ),
                ),
                const SizedBox(width: 8),

                // Actions
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _pickAndUploadImage(index),
                      tooltip: "Upload image",
                      icon: const Icon(Icons.cloud_upload_outlined, color: Color(0xFF2563EB)),
                    ),
                    IconButton(
                      onPressed: () {
                        if (_imageCtrls.length == 1) {
                          _imageCtrls[0].text = '';
                          setState(() {});
                          return;
                        }
                        setState(() {
                          final ctrl = _imageCtrls.removeAt(index);
                          ctrl.dispose();
                        });
                      },
                      tooltip: "Remove",
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _imageCtrls.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: const Text("Add another image"),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              side: BorderSide(color: Colors.black.withOpacity(0.12)),
            ),
          ),
        ),
      ],
    );
  }

  // ====================== Summary / Live Preview ======================
  Widget _buildSummaryCard() {
    final title = _title.text.trim().isEmpty ? "Untitled service" : _title.text.trim();
    final category = _selectedCategory ?? "Not set";
    final price = _price.text.trim().isEmpty ? "-" : _price.text.trim();
    final cur = _currency.text.trim().isEmpty ? "USD" : _currency.text.trim();
    final duration = _duration.text.trim().isEmpty ? "-" : "${_duration.text.trim()} min";
    final tags = _tags.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final cover = _imageCtrls
        .map((c) => ApiConfig.fixAssetUrl(c.text.trim()))
        .firstWhere((u) => u.isNotEmpty, orElse: () => '');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E7F1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Live preview", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 10),

          // Preview card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                  color: Colors.black.withOpacity(0.04),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cover
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  child: Container(
                    height: 140,
                    width: double.infinity,
                    color: const Color(0xFFEAF4F8),
                    child: cover.isNotEmpty
                        ? Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                          )
                        : const Center(
                            child: Icon(Icons.image_outlined, color: Color(0xFF7C8DA3), size: 30),
                          ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _pill(Icons.category_outlined, category),
                          const SizedBox(width: 8),
                          _pill(Icons.schedule_outlined, duration),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.attach_money_outlined, size: 18, color: Color(0xFF2F8CA5)),
                          const SizedBox(width: 6),
                          Text("$price $cur",
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _ink)),
                        ],
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tags.take(8).map((t) => _chip(t)).toList(),
                        )
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          Text(
            "Tip: choose a clear title + add 1–3 images to increase bookings.",
            style: TextStyle(color: Colors.grey[700], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _primary.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF2F8CA5)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _ink)),
        ],
      ),
    );
  }

  Widget _chip(String t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Text(
        t,
        style: const TextStyle(fontSize: 12, color: _ink, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ====================== BUILD ======================
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    final isSmall = MediaQuery.of(context).size.width < 820;
    final maxWidth = isSmall ? 900.0 : 1180.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              isEditing ? "Edit Service" : "Create New Service",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            child: Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                      color: Colors.black.withOpacity(0.06),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: LayoutBuilder(
                    builder: (context, cons) {
                      final wide = cons.maxWidth >= 980;

                      // Left: form
                      final left = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            icon: Icons.design_services_outlined,
                            title: isEditing ? "Update your service" : "Publish a new service",
                            subtitle: "Add details, set pricing, and upload images — like SaaS platforms.",
                          ),
                          const SizedBox(height: 14),
                          Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                          const SizedBox(height: 16),

                          // Details section
                          _sectionTitle(
                            icon: Icons.description_outlined,
                            title: "Service details",
                            subtitle: "Title, category, and description that customers understand quickly.",
                          ),
                          const SizedBox(height: 12),
                          _tf(
                            "Title",
                            _title,
                            required: true,
                            hint: "e.g., UI/UX Audit for Mobile Apps",
                            prefix: const Icon(Icons.title_outlined),
                          ),
                          const SizedBox(height: 12),
                          _categoryDropdown(),
                          const SizedBox(height: 12),
                          _ta(
                            "Description",
                            _description,
                            required: true,
                            hint: "Explain what you deliver, what the customer should expect, and how you work.",
                          ),
                          const SizedBox(height: 14),

                          // Pricing section
                          _sectionTitle(
                            icon: Icons.payments_outlined,
                            title: "Pricing",
                            subtitle: "Set a clear price and duration — customers prefer transparent services.",
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _tf(
                                  "Price",
                                  _price,
                                  keyboard: TextInputType.number,
                                  required: true,
                                  hint: "e.g., 50",
                                  prefix: const Icon(Icons.attach_money_outlined),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _tf(
                                  "Currency",
                                  _currency,
                                  hint: "USD",
                                  prefix: const Icon(Icons.currency_exchange_outlined),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _tf(
                                  "Duration (min)",
                                  _duration,
                                  keyboard: TextInputType.number,
                                  required: true,
                                  hint: "60",
                                  prefix: const Icon(Icons.schedule_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _tf(
                            "Tags (comma separated)",
                            _tags,
                            hint: "e.g., ui, ux, figma, audit",
                            prefix: const Icon(Icons.sell_outlined),
                          ),
                          const SizedBox(height: 18),

                          // Save row
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _saving ? null : () => Navigator.pop(context, false),
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text("Back"),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    side: BorderSide(color: Colors.black.withOpacity(0.12)),
                                    foregroundColor: _ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _saving ? null : _save,
                                  icon: _saving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.check_circle_outline),
                                  label: Text(_saving ? "Saving..." : (isEditing ? "Save changes" : "Publish service")),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );

                      // Right: media + preview
                      final right = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionTitle(
                            icon: Icons.photo_library_outlined,
                            title: "Media",
                            subtitle: "Upload images or paste URLs (supports Web + Mobile).",
                          ),
                          const SizedBox(height: 12),
                          _imagesBlock(),
                          const SizedBox(height: 14),
                          _buildSummaryCard(),
                        ],
                      );

                      if (!wide) {
                        // Mobile / narrow
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            left,
                            const SizedBox(height: 22),
                            Divider(height: 1, color: Colors.black.withOpacity(0.06)),
                            const SizedBox(height: 18),
                            right,
                          ],
                        );
                      }

                      // Wide layout
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 18),
                          SizedBox(width: 420, child: right),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
