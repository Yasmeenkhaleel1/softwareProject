import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceFormPage extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const ServiceFormPage({super.key, this.existing});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
  static const baseUrl = "http://localhost:5000";
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
      final imgs = (s['images'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
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

  /// ✅ اختيار ورفع صورة من المعرض إلى السيرفر
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
      // ✅ Web
      request.files.add(http.MultipartFile.fromBytes('gallery', fileBytes, filename: fileName));
    } else if (result.files.single.path != null) {
      // ✅ Mobile / Desktop
      request.files.add(await http.MultipartFile.fromPath('gallery', result.files.single.path!));
    } else {
      throw Exception("No file data found");
    }

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);

    if (res.statusCode == 200 || res.statusCode == 201) {
      final data = jsonDecode(res.body);
      final imageUrl = data['files']?[0]?['url'] ?? '';
      if (imageUrl.isNotEmpty) {
        setState(() {
          _imageCtrls[index].text = imageUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Image uploaded successfully")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed: ${res.body}")),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error uploading image: $e")),
    );
  }
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Saved successfully")));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: Text(isEdit ? "Edit Service" : "Add Service",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                _tf("Title", _title, required: true),
                _categoryDropdown(),
                Row(
                  children: [
                    Expanded(
                        child: _tf("Price", _price,
                            keyboard: TextInputType.number, required: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _tf("Currency", _currency)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _tf("Duration (min)", _duration,
                            keyboard: TextInputType.number, required: true)),
                  ],
                ),
                _tf("Tags (comma separated)", _tags),
                _ta("Description", _description, required: true),
                const SizedBox(height: 8),
                _imagesBlock(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF62C6D9)),
                    child: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ),
              ],
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
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
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

  Widget _tf(String label, TextEditingController c,
      {TextInputType? keyboard, bool required = false}) {
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
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child:
              Text("Images", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        ..._imageCtrls.map((c) {
          final index = _imageCtrls.indexOf(c);
          return Row(
            children: [
              Expanded(child: _tf("Image URL", c)),
              IconButton(
                onPressed: () => _pickAndUploadImage(index),
                icon: const Icon(Icons.photo_library, color: Colors.blueAccent),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _imageCtrls.remove(c);
                  });
                },
                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
              ),
            ],
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _imageCtrls.add(TextEditingController())),
          icon: const Icon(Icons.add),
          label: const Text("Add Image"),
        )
      ],
    );
  }
}
