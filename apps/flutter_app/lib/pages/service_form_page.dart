// ✅ نفس الاستيرادات تماماً
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ServiceFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const ServiceFormPage({super.key, this.existing, required Map<String, dynamic> service});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
String get baseUrl {
  if (kIsWeb) {
    return "http://localhost:5000";
  } else {
    return "http://10.0.2.2:5000";
  }
}
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
      final imgs = (s['images'] as List?)?.map((e) => e.toString()).toList() ?? [];
      if (imgs.isNotEmpty) {
        _imageCtrls.clear();
        _imageCtrls.addAll(imgs.map((u) => TextEditingController(text: u)));
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
        request.files.add(http.MultipartFile.fromBytes('gallery', fileBytes, filename: fileName));
      } else if (result.files.single.path != null) {
        request.files.add(await http.MultipartFile.fromPath('gallery', result.files.single.path!));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _errorMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      "tags": _tags.text.split(",").map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList(),
      "images": _imageCtrls.map((c) => c.text.trim()).where((e) => e.isNotEmpty).toList(),
    };

    http.Response res;
    if (widget.existing == null) {
      res = await http.post(
        Uri.parse("$baseUrl/api/services"),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } else {
      final id = widget.existing!['_id'];
      res = await http.put(
        Uri.parse("$baseUrl/api/services/$id"),
        headers: {'Authorization': 'Bearer $t', 'Content-Type': 'application/json'},
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
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF62C6D9),
        title: Text(
          widget.existing != null ? "Edit Service" : "Add Service",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const SizedBox(height: 6),
                      const Text("Service Information",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 16),
                      
                      _tf("Title", _title, required: true),
                      _categoryDropdown(),

                      Row(
                        children: [
                          Expanded(child: _tf("Price", _price, keyboard: TextInputType.number, required: true)),
                          const SizedBox(width: 10),
                          Expanded(child: _tf("Currency", _currency)),
                          const SizedBox(width: 10),
                          Expanded(child: _tf("Duration (min)", _duration, keyboard: TextInputType.number, required: true)),
                        ],
                      ),

                      _tf("Tags (comma separated)", _tags),
                      _ta("Description", _description, required: true),
                      const SizedBox(height: 16),

                      const Divider(),
                      const SizedBox(height: 16),
                      const Text("Images", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      _imagesBlock(),
                      const SizedBox(height: 24),

                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF62C6D9),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(_saving ? 'Saving...' : 'Save', style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
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
        initialValue: _selectedCategory,
        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (val) => setState(() => _selectedCategory = val),
        decoration: InputDecoration(
          labelText: "Category",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
    );
  }

  Widget _tf(String label, TextEditingController c, {TextInputType? keyboard, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }

  Widget _ta(String label, TextEditingController c, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        minLines: 4,
        maxLines: 8,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
        ),
      ),
    );
  }

  Widget _imagesBlock() {
    return Column(
      children: [
        ..._imageCtrls.map((c) {
          final index = _imageCtrls.indexOf(c);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: _tf("Image URL", c)),
                IconButton(
                  onPressed: () => _pickAndUploadImage(index),
                  icon: const Icon(Icons.photo_library, color: Colors.blueAccent),
                ),
                IconButton(
                  onPressed: () => setState(() => _imageCtrls.remove(c)),
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _imageCtrls.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text("Add Image"),
        )
      ],
    );
  }
}
