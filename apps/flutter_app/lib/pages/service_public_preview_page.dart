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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
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

  // ===== UI constants (design only) =====
  static const Color themeBlue = Color(0xFF62C6D9);
  static const Color ink = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);

  bool get isMobile => MediaQuery.of(context).size.width < 860;

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final images = (service['images'] as List?)?.cast<String>() ?? [];
    final imageUrl = images.isNotEmpty
        ? images.first
        : "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";

    final title = (service['title'] ?? "Service Preview").toString();
    final category = (service['category'] ?? "SERVICE").toString();
    final duration = (service['durationMinutes'] ?? 0).toString();
    final price = (service['price'] ?? 0).toString();
    final currency = (service['currency'] ?? "USD").toString();
    final desc = (service['description'] ?? "...").toString();

    final maxW = isMobile ? 980.0 : 1180.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: themeBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ================= HERO =================
                _HeroHeader(
                  imageUrl: imageUrl,
                  category: category,
                  isMobile: isMobile,
                ),

                const SizedBox(height: 14),

                // ================= CONTENT GRID =================
                LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth >= 980;

                    final left = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SaasCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _Pill(
                                      icon: Icons.timer_outlined,
                                      text: "$duration min",
                                      bg: themeBlue.withOpacity(0.12),
                                      fg: themeBlue,
                                    ),
                                    _Pill(
                                      icon: Icons.star_rounded,
                                      text: "${_ratingAvg.toStringAsFixed(1)} ★",
                                      bg: Colors.amber.withOpacity(0.14),
                                      fg: Colors.amber.shade800,
                                    ),
                                    _Pill(
                                      icon: Icons.category_outlined,
                                      text: category,
                                      bg: Colors.indigo.withOpacity(0.10),
                                      fg: Colors.indigo,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Divider(height: 1),
                                const SizedBox(height: 14),
                                const Text(
                                  "About this service",
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ink),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    color: ink,
                                    height: 1.6,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ================= RATING =================
                        _SaasCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.star_outline, color: Colors.amber),
                                    SizedBox(width: 8),
                                    Text(
                                      "Rate this service",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ink),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Your rating helps customers choose and improves quality.",
                                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                ),
                                const SizedBox(height: 14),
                                RatingBar.builder(
                                  initialRating: _ratingAvg,
                                  allowHalfRating: true,
                                  itemCount: 5,
                                  itemSize: 34,
                                  unratedColor: Colors.grey.shade300,
                                  itemBuilder: (_, __) => const Icon(Icons.star, color: Colors.amber),
                                  onRatingUpdate: (rating) async {
                                    // ✅ نفس اللوجيك
                                    final prefs = await SharedPreferences.getInstance();
                                    final token = prefs.getString('token') ?? '';
                                    if (token.isEmpty) {
                                      _showDialog(context, "Login Required", "Please log in to rate services.");
                                      return;
                                    }

                                    setState(() => _ratingAvg = rating);

                                    final res = await http.post(
                                      Uri.parse(
                                        "http://localhost:5000/api/services/${service['_id']}/rate",
                                      ),
                                      headers: {
                                        'Authorization': 'Bearer $token',
                                        'Content-Type': 'application/json'
                                      },
                                      body: jsonEncode({'rating': rating}),
                                    );

                                    if (res.statusCode == 200) {
                                      final body = jsonDecode(res.body);
                                      setState(() {
                                        _ratingAvg = body['ratingAvg']?.toDouble() ?? rating;
                                      });
                                      _showDialog(context, "Success", "⭐ Rated (${_ratingAvg.toStringAsFixed(1)})");
                                    } else {
                                      _showDialog(context, "Error", "Error: ${res.body}");
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // ================= GALLERY =================
                        if (images.length > 1) ...[
                          const SizedBox(height: 14),
                          _SaasCard(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(Icons.photo_library_outlined, color: ink),
                                      SizedBox(width: 8),
                                      Text(
                                        "Gallery",
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ink),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 148,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: images.length,
                                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                                      itemBuilder: (_, i) {
                                        return MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: CachedNetworkImage(
                                              imageUrl: images[i],
                                              width: 210,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(
                                                width: 210,
                                                color: Colors.grey.shade200,
                                                child: const Center(child: CircularProgressIndicator()),
                                              ),
                                              errorWidget: (_, __, ___) => Container(
                                                width: 210,
                                                color: Colors.grey.shade200,
                                                child: const Center(child: Icon(Icons.broken_image_outlined)),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );

                    final right = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ================= PRICE / CTA =================
                        _SaasCard(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.payments_outlined, color: ink),
                                    SizedBox(width: 8),
                                    Text(
                                      "Pricing",
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: ink),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text("Price", style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "$price ",
                                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: ink),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        currency,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: muted),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Duration: $duration minutes",
                                  style: const TextStyle(color: muted, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showDialog(
                                      context,
                                      "Booking",
                                      "Booking feature coming soon!",
                                    ),
                                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                                    label: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      child: Text(
                                        "Book Now",
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: themeBlue,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: themeBlue.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: themeBlue.withOpacity(0.18)),
                                  ),
                                  child: const Text(
                                    "Tip: Add clear images + a detailed description to increase bookings.",
                                    style: TextStyle(fontSize: 12.5, color: ink, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );

                    if (!wide) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          right,
                          const SizedBox(height: 14),
                          left,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 14),
                        SizedBox(width: 360, child: right),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====================== Components ======================

class _SaasCard extends StatelessWidget {
  final Widget child;
  const _SaasCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            blurRadius: 22,
            offset: const Offset(0, 12),
            color: Colors.black.withOpacity(0.05),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  const _Pill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final String imageUrl;
  final String category;
  final bool isMobile;

  const _HeroHeader({
    required this.imageUrl,
    required this.category,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    const themeBlue = Color(0xFF62C6D9);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            height: isMobile ? 240 : 320,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              height: isMobile ? 240 : 320,
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (_, __, ___) => Container(
              height: isMobile ? 240 : 320,
              color: Colors.grey.shade200,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          ),
          Container(
            height: isMobile ? 240 : 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(.55),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.category_outlined, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: themeBlue.withOpacity(0.90),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.verified_outlined, size: 16, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    "Preview",
                    style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
