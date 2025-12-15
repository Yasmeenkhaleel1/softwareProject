// ✅ نفس الاستيرادات تقريباً لكن بدون dart:io ومع ApiConfig
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart'; // تأكدي من المسار

class ServiceFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const ServiceFormPage({super.key, this.existing});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  // 🔹 بدال localhost الثابت → نستخدم ApiConfig.baseUrl عشان يشتغل Web + Mobile
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

  final List<String> _categories = [
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
      final imgs =
          (s['images'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (imgs.isNotEmpty) {
        _imageCtrls.clear();
        _imageCtrls.addAll(
          imgs.map((u) => TextEditingController(text: u)),
        );
      }
    }
  }

  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') ?? '';
  }

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
      SnackBar(content: Text(msg)),
    );
  }

  void _errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF62C6D9),
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              isEditing ? "Edit Service" : "Create New Service",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;

                      // 🔹 Header داخل الكارد (عنوان + وصف صغير)
                      final header = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF62C6D9).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.design_services_outlined,
                                  color: Color(0xFF2F8CA5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing
                                        ? "Update your service"
                                        : "Publish a new service",
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Describe your expertise, set pricing, and showcase visuals for customers.",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                        ],
                      );

                      // 🔹 العمود الأيسر: المعلومات الأساسية
                      final leftColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Service Details",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _tf(
                            "Title",
                            _title,
                            required: true,
                          ),
                          _categoryDropdown(),
                          Row(
                            children: [
                              Expanded(
                                child: _tf(
                                  "Price",
                                  _price,
                                  keyboard: TextInputType.number,
                                  required: true,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _tf(
                                  "Currency",
                                  _currency,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _tf(
                                  "Duration (min)",
                                  _duration,
                                  keyboard: TextInputType.number,
                                  required: true,
                                ),
                              ),
                            ],
                          ),
                          _tf(
                            "Tags (comma separated)",
                            _tags,
                          ),
                          _ta(
                            "Description",
                            _description,
                            required: true,
                          ),
                        ],
                      );

                      // 🔹 العمود الأيمن: الصور + ملخص بسيط
                      final rightColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Media & Preview",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _imagesBlock(),
                          const SizedBox(height: 16),
                          _buildServiceSummaryCard(),
                        ],
                      );

                      final saveButton = Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF62C6D9),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline,
                                  size: 20,
                                ),
                          label: Text(
                            _saving ? 'Saving...' : 'Save service',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );

                      if (isWide) {
                        // 💻 Web / شاشات واسعة: قسمين جنب بعض
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            header,
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: leftColumn),
                                const SizedBox(width: 24),
                                SizedBox(
                                  width: 360,
                                  child: rightColumn,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            saveButton,
                          ],
                        );
                      } else {
                        // 📱 Mobile / شاشات صغيرة: عمود واحد مرتّب
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            header,
                            leftColumn,
                            const SizedBox(height: 24),
                            rightColumn,
                            const SizedBox(height: 24),
                            saveButton,
                          ],
                        );
                      }
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

  Widget _categoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        items: _categories
            .map(
              (c) => DropdownMenuItem(
                value: c,
                child: Text(c),
              ),
            )
            .toList(),
        onChanged: (val) => setState(() => _selectedCategory = val),
        decoration: InputDecoration(
          labelText: "Category",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _tf(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }

  Widget _ta(
    String label,
    TextEditingController c, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        minLines: 4,
        maxLines: 8,
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }

  Widget _imagesBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._imageCtrls.map((c) {
          final index = _imageCtrls.indexOf(c);
          final fixedUrl = ApiConfig.fixAssetUrl(c.text.trim());

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Preview صغير على اليسار (لو فيه URL)
                if (fixedUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: const Color(0xFFE5EDF7),
                      child: Image.network(
                        fixedUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          size: 26,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5EDF7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF7C8DA3),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: _tf("Image URL", c),
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: () => _pickAndUploadImage(index),
                      tooltip: "Upload image",
                      icon: const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.blueAccent,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _imageCtrls.remove(c)),
                      tooltip: "Remove",
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _imageCtrls.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text("Add Image"),
        ),
      ],
    );
  }

  Widget _buildServiceSummaryCard() {
    final price = _price.text.trim().isEmpty ? "-" : _price.text.trim();
    final duration =
        _duration.text.trim().isEmpty ? "-" : "${_duration.text.trim()} min";
    final category = _selectedCategory ?? "Not set";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE0E7F1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Quick summary",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          _summaryRow(
            icon: Icons.category_outlined,
            label: "Category",
            value: category,
          ),
          _summaryRow(
            icon: Icons.attach_money_outlined,
            label: "Price",
            value: "$price ${_currency.text}",
          ),
          _summaryRow(
            icon: Icons.schedule_outlined,
            label: "Duration",
            value: duration,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF2F8CA5),
          ),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
