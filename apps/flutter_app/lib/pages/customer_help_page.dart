import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api/api_service.dart';

class CustomerHelpPage extends StatefulWidget {
  final String? initialBookingId;

  const CustomerHelpPage({super.key, this.initialBookingId});

  @override
  State<CustomerHelpPage> createState() => _CustomerHelpPageState();
}

class _CustomerHelpPageState extends State<CustomerHelpPage> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();

  List<dynamic> _bookings = [];
  String? _selectedBookingId;
  String _selectedType = "QUALITY";

  bool _loadingBookings = true;
  bool _submitting = false;
  String? _loadError;

  // 🟣 المرفقات (صور / فيديو / PDF / ملفات عادية)
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _loadingBookings = true;
      _loadError = null;
    });

    try {
      final items = await ApiService.getDisputableBookings();

      setState(() {
        _bookings = items;
        if (widget.initialBookingId != null) {
          final exists =
              _bookings.any((b) => b["_id"].toString() == widget.initialBookingId);
          _selectedBookingId = exists ? widget.initialBookingId : null;
        }
      });
    } catch (e) {
      setState(() {
        _loadError = e.toString();
      });
    } finally {
      setState(() {
        _loadingBookings = false;
      });
    }
  }

  /*───────────────────────────────
    🟣 اختيار المرفقات من الجهاز
  ───────────────────────────────*/
  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true, // مهم للويب عشان نستخدم bytes
      type: FileType.custom,
      allowedExtensions: [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'pdf',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'doc',
        'docx'
      ],
    );

    if (result == null) return;

    setState(() {
      _attachments.addAll(result.files);
    });
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  /*───────────────────────────────
    🟣 رفع المرفقات للسيرفر
  ───────────────────────────────*/
  Future<List<String>> _uploadAttachments() async {
    if (_attachments.isEmpty) return [];

    final token = await ApiService.getToken();
    final uri = Uri.parse('${ApiService.baseUrl}/upload/disputes');

    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    for (final file in _attachments) {
      if (file.bytes == null) continue;

      request.files.add(
        http.MultipartFile.fromBytes(
          'files', // نفس الاسم الموجود في upload.routes.js
          file.bytes!,
          filename: file.name,
        ),
      );
    }

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 400) {
      throw Exception("Upload failed (${res.statusCode}): ${res.body}");
    }

    final body = jsonDecode(res.body);
    final List urls = body['urls'] ?? body['attachments'] ?? [];
    return urls.map((e) => e.toString()).toList();
  }

  /*───────────────────────────────
    🟣 إرسال الفورم وفتح Dispute
  ───────────────────────────────*/
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please choose a booking.")),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // 1) نرفع الملفات (لو فيه)
      final attachmentUrls = await _uploadAttachments();

      // 2) ننشئ الـ Dispute
      await ApiService.createDispute(
        bookingId: _selectedBookingId!,
        message: _messageController.text.trim(),
        type: _selectedType,
        attachments: attachmentUrls,
      );

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Request submitted",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Your dispute has been opened.\nOur team will review it and contact you soon.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit: $e")),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF62C6D9);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        title: const Text(
          "Help & Support",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: accent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE7F5F8), Color(0xFFF7FBFD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 32 : 16,
                    vertical: 24,
                  ),
                  child: _loadingBookings
                      ? const Center(child: CircularProgressIndicator())
                      : _loadError != null
                          ? Center(
                              child: Text(
                                _loadError!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            )
                          : _buildCard(accent, isWide),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(Color accent, bool isWide) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wideForm = constraints.maxWidth >= 720;

              // 🔹 العمود الأيسر (الحجز + نوع المشكلة)
              final leftColumnChildren = <Widget>[
                DropdownButtonFormField<String>(
                  value: _selectedBookingId,
                  isExpanded:
                      true, // ✅ مهم جداً عشان ما يصير overflow على الموبايل
                  decoration: const InputDecoration(
                    labelText: "Select booking",
                    border: OutlineInputBorder(),
                  ),
                  items: _bookings.map((b) {
                    final code = (b["code"] ?? "").toString();
                    final status = (b["status"] ?? "").toString();
                    final amount = b["payment"]?["amount"] ?? 0;
                    final currency = b["payment"]?["currency"] ?? "USD";
                    final title = b["serviceSnapshot"]?["title"] ?? "";

                    return DropdownMenuItem<String>(
                      value: b["_id"].toString(),
                      child: Text(
                        "$code • $title • $amount $currency • $status",
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() => _selectedBookingId = v);
                  },
                  validator: (v) =>
                      v == null ? "Please choose a booking" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  isExpanded: true, // ✅ برضو عشان السهم + النص
                  decoration: const InputDecoration(
                    labelText: "Issue type",
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: "QUALITY",
                      child: Text("Session quality issue"),
                    ),
                    DropdownMenuItem(
                      value: "NO_SHOW",
                      child: Text("Expert did not show up"),
                    ),
                    DropdownMenuItem(
                      value: "LATE",
                      child: Text("Expert was very late"),
                    ),
                    DropdownMenuItem(
                      value: "OTHER",
                      child: Text("Other"),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedType = v);
                  },
                ),
              ];

              // 🔹 العمود الأيمن (الوصف + المرفقات)
              final rightColumnChildren = <Widget>[
                TextFormField(
                  controller: _messageController,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: "Describe your issue",
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                    hintText:
                        "Please describe what happened, when it happened, and what you expect as a solution.",
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Please describe the problem";
                    }
                    if (v.trim().length < 10) {
                      return "Please add more details";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Icon(Icons.attachment, size: 20, color: Colors.grey),
                    const SizedBox(width: 6),
                    const Text(
                      "Attachments (optional)",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _pickAttachments,
                      icon: const Icon(Icons.add),
                      label: const Text("Add files"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _attachments.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE1E5EC)),
                        ),
                        child: const Text(
                          "You can attach screenshots, invoices, or short videos to support your case.",
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13.5),
                        ),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            List.generate(_attachments.length, (index) {
                          final f = _attachments[index];
                          final isImage = _isImageFile(f.name);

                          return Container(
                            width: 170,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9FC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE0E4F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (isImage && f.bytes != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      f.bytes!,
                                      height: 80,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.insert_drive_file,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "${(f.size / 1024).toStringAsFixed(1)} KB",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints(),
                                      onPressed: () =>
                                          _removeAttachment(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
              ];

              return ListView(
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEBF7FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: Color(0xFF285E6E),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Report a problem or request a refund",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Color(0xFF285E6E),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Choose the session, explain the issue, and attach any images or documents that support your request.",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Stepper-like row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      _StepDot(label: "1. Booking"),
                      _StepConnector(),
                      _StepDot(label: "2. Issue"),
                      _StepConnector(),
                      _StepDot(label: "3. Attachments"),
                      _StepConnector(),
                      _StepDot(label: "4. Submit"),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 🔹 Responsive: عمود واحد على الموبايل، عمودين على الويب
                  if (!wideForm) ...[
                    ...leftColumnChildren,
                    const SizedBox(height: 16),
                    ...rightColumnChildren,
                  ] else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(children: leftColumnChildren),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(children: rightColumnChildren),
                        ),
                      ],
                    ),

                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.send),
                      label: const Text(
                        "Submit request",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/*───────────────────────────────
  عناصر صغيرة للـ Stepper
───────────────────────────────*/
class _StepDot extends StatelessWidget {
  final String label;
  const _StepDot({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF62C6D9),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}

class _StepConnector extends StatelessWidget {
  const _StepConnector();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFBFD9E4),
      ),
    );
  }
}
