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
  State<ServicePublicPreviewPage> createState() =>
      _ServicePublicPreviewPageState();
}

class _ServicePublicPreviewPageState extends State<ServicePublicPreviewPage> {
  late double _ratingAvg;

  @override
  void initState() {
    super.initState();
    _ratingAvg = (widget.service['ratingAvg'] ?? 0).toDouble();
  }

  Future<void> _showDialog(
      BuildContext context, String title, String message) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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
        : "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";

    final themeBlue = const Color(0xFF62C6D9);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F8),
      appBar: AppBar(
        elevation: 4,
        backgroundColor: themeBlue,
        title: Text(
          service['title'] ?? "Service Preview",
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // ✅ مركز الصفحة وعرض ثابت للويب فقط
      body: Center(
        child: Container(
          width: 1100,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 40),
            child: Column(
              children: [
                // ================= HEADER IMAGE =================
                Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 350,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      height: 350,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.black.withOpacity(.55),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 25,
                      left: 25,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.65),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          service['category'] ?? "SERVICE",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              letterSpacing: 1),
                        ),
                      ),
                    )
                  ],
                ),

                // ================= TITLE CARD =================
                Container(
                  transform: Matrix4.translationValues(0, -18, 0),
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12.withOpacity(.08),
                          blurRadius: 15)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service['title'] ?? "",
                        style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87),
                      ),
                      const SizedBox(height: 12),

                      // ✅ Wrap بدل Row لمنع overflow
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Chip(
                            backgroundColor: themeBlue.withOpacity(.15),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer,
                                    size: 17, color: themeBlue),
                                const SizedBox(width: 6),
                                Text("${service['durationMinutes']} min"),
                              ],
                            ),
                          ),
                          Chip(
                            backgroundColor: Colors.amber.withOpacity(.15),
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    size: 17, color: Colors.amber),
                                const SizedBox(width: 6),
                                Text("${_ratingAvg.toStringAsFixed(1)} ★"),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      Text(
                        service['description'] ?? "...",
                        style: const TextStyle(
                            color: Colors.black87,
                            height: 1.6,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // ================= PRICE CARD =================
              Container(
  margin: const EdgeInsets.symmetric(horizontal: 24),
  padding: const EdgeInsets.all(26),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
          color: Colors.black12.withOpacity(.05),
          blurRadius: 10)
    ],
  ),
  child: Row(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Price", style: TextStyle(color: Colors.black87)),
          Text(
            "${service['price']} ${service['currency']}",
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
        ],
      ),
      const Spacer(),

      // ✅ زر واضح على الويب
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ElevatedButton.icon(
            onPressed: () => _showDialog(
              context,
              "Booking",
              "Booking feature coming soon!",
            ),
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            label: const Text(
              "Book Now",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeBlue,
              elevation: 4,
              shadowColor: Colors.black26,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
),


                // ================= RATING BOX =================
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12.withOpacity(.05),
                          blurRadius: 10)
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text("Rate this service",
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 14),
                      RatingBar.builder(
                        initialRating: _ratingAvg,
                        allowHalfRating: true,
                        itemCount: 5,
                        itemSize: 34,
                        unratedColor: Colors.grey.shade300,
                        itemBuilder: (_, __) =>
                            const Icon(Icons.star, color: Colors.amber),
                        onRatingUpdate: (rating) async {
                          final prefs =
                              await SharedPreferences.getInstance();
                          final token = prefs.getString('token') ?? '';
                          if (token.isEmpty) {
                            _showDialog(context, "Login Required",
                                "Please log in to rate services.");
                            return;
                          }

                          setState(() => _ratingAvg = rating);

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
                                "⭐ Rated (${_ratingAvg.toStringAsFixed(1)})");
                          } else {
                            _showDialog(
                                context, "Error", "Error: ${res.body}");
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // ================= GALLERY =================
                if (images.length > 1) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Row(
                      children: const [
                        Icon(Icons.image, color: Colors.black54),
                        SizedBox(width: 6),
                        Text("Gallery",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 24),
                      itemCount: images.length,
                      itemBuilder: (_, i) => MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          margin: const EdgeInsets.only(right: 14),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: images[i],
                              width: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
