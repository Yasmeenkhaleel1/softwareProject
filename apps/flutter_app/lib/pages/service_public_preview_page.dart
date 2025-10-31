import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ServicePublicPreviewPage extends StatefulWidget {
  final Map<String, dynamic> service;
  const ServicePublicPreviewPage({super.key, required this.service});

  @override
  State<ServicePublicPreviewPage> createState() => _ServicePublicPreviewPageState();
}

class _ServicePublicPreviewPageState extends State<ServicePublicPreviewPage> {
  late double _ratingAvg;

  @override
  void initState() {
    super.initState();
    _ratingAvg = (widget.service['ratingAvg'] ?? 0).toDouble();
  }

  Future<void> _showDialog(BuildContext context, String title, String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final images = (service['images'] as List?)?.cast<String>() ?? [];
    final imageUrl = images.isNotEmpty
        ? images.first
        : "https://cdn-icons-png.flaticon.com/512/3135/3135715.png"; // صورة افتراضية

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: Text(
          service['title'] ?? "Service Preview",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 3,
        shadowColor: Colors.teal.shade100,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // صورة الغلاف
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 260,
                    color: Colors.grey.shade200,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 260,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 60),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      service['category']?.toString().toUpperCase() ?? "SERVICE",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 1),
                    ),
                  ),
                )
              ],
            ),

            // تفاصيل الخدمة
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service['title'] ?? "",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.timer, color: Colors.teal, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "${service['durationMinutes'] ?? 60} min session",
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const Spacer(),
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        "${_ratingAvg.toStringAsFixed(1)} ★",
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    service['description'] ??
                        "No description available for this service.",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.attach_money, size: 30, color: Colors.teal),
                            const SizedBox(width: 8),
                            Text(
                              "${service['price'] ?? 0} ${service['currency'] ?? 'USD'}",
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEAF1F2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.shopping_cart),
                              label: const Text("Book Now"),
                              onPressed: () {
                                _showDialog(context, "Booking",
                                    "Booking feature coming soon!");
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: RatingBar.builder(
                            initialRating: _ratingAvg,
                            minRating: 1,
                            allowHalfRating: true,
                            itemCount: 5,
                            itemSize: 30,
                            unratedColor: Colors.grey.shade300,
                            itemBuilder: (context, _) =>
                                const Icon(Icons.star, color: Colors.amber),
                            onRatingUpdate: (rating) async {
                              final prefs = await SharedPreferences.getInstance();
                              final token = prefs.getString('token') ?? '';
                              if (token.isEmpty) {
                                _showDialog(context, "Login Required",
                                    "Please log in to rate services.");
                                return;
                              }

                              // حفظ التقييم مؤقتًا مباشرة على الشاشة
                              setState(() {
                                _ratingAvg = rating;
                              });

                              final res = await http.post(
                                Uri.parse(
                                    "http://localhost:5000/api/services/${service['_id']}/rate"),
                                headers: {
                                  'Authorization': 'Bearer $token',
                                  'Content-Type': 'application/json'
                                },
                                body: jsonEncode({'rating': rating}),
                              );

                              if (res.statusCode == 200) {
                                final body = jsonDecode(res.body);
                                setState(() {
                                  _ratingAvg =
                                      body['ratingAvg']?.toDouble() ?? rating;
                                });
                                _showDialog(context, "Success",
                                    "⭐ Rated successfully (${_ratingAvg.toStringAsFixed(1)})");
                              } else {
                                _showDialog(context, "Error", "Error: ${res.body}");
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // معرض الصور الإضافية
            if (images.length > 1)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Gallery",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        itemBuilder: (context, i) => Container(
                          margin: const EdgeInsets.only(right: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: images[i],
                              width: 160,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade200,
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.broken_image),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
