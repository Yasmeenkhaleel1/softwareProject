import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'service_public_preview_page.dart';
import 'ExpertDetailPage.dart';

class SearchPage extends StatefulWidget {
  final String? preselectedCategory;   // ⭐ تمت إضافتها

  const SearchPage({super.key, this.preselectedCategory});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final String baseUrl = "http://localhost:5000";

  List<dynamic> results = [];
  bool loading = false;

  String query = "";
  String category = "All";
  String sort = "rating_desc";

  final List<String> categories = [
    "All",
    "Design",
    "Marketing",
    "Business",
    "Programming",
    "Mobile",
    "Backend",
  ];

  /* ------------------------ INIT (تفعيل الفلترة الجاهزة) ------------------------ */
  @override
  void initState() {
    super.initState();

    // لو وصل تخصص جاهز من الصفحة الرئيسية
    if (widget.preselectedCategory != null) {
      category = widget.preselectedCategory!;
      _search();
    }
  }

  /* ---------------------------------------------------------------------- */
  /*       🔥 FIX: FUNCTION THAT RETURNS EXPERT IN ANY POSSIBLE LOCATION     */
  /* ---------------------------------------------------------------------- */
  Map<String, dynamic> extractExpert(Map<String, dynamic> s) {
    final possible = [
      "expert",
      "expertId",
      "owner",
      "createdBy",
      "user",
    ];

    for (final key in possible) {
      if (s[key] is Map<String, dynamic>) return s[key];
    }

    // fallback لو كانت البيانات مباشرة داخل السرفيس
    return {
      "name": s["expertName"] ?? "Unknown",
      "profileImageUrl": s["profileImageUrl"] ?? "",
      "specialization": s["expertSpecialization"] ?? "",
      "ratingAvg": s["ratingAvg"] ?? 0,
    };
  }

  /* ---------------------------- SEARCH API ------------------------------- */
  Future<void> _search() async {
    setState(() => loading = true);

    try {
      final uri = Uri.parse(
        "$baseUrl/api/services/public/search?q=$query&category=$category&sort=$sort",
      );

      final res = await http.get(uri, headers: {
        "Content-Type": "application/json",
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          results = data["items"] ?? [];
        });
      } else {
        results = [];
      }
    } catch (e) {
      results = [];
    }

    setState(() => loading = false);
  }

  /* --------------------------- SERVICE CARD UI --------------------------- */
  Widget _buildServiceCard(Map<String, dynamic> s) {
    final serviceId = s["_id"];
    final title = s["title"] ?? "Untitled";
    final price = (s["price"] ?? 0).toDouble();
    final currency = s["currency"] ?? "USD";
    final rating = (s["ratingAvg"] ?? 0).toDouble();
    final cat = s["category"] ?? "-";

    /* -------- FIX: يلتقط الخبير مهما كان اسم الحقل -------- */
    final expert = extractExpert(s);

    final expertName = expert["name"] ?? "Unknown";
    final expertSpec = expert["specialization"] ?? "";
    final expertImg = expert["profileImageUrl"] ?? "";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServicePublicPreviewPage(service: s),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Row(
          children: [
            // IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 85,
                height: 85,
                color: Colors.grey.shade200,
                child: (s["images"] != null &&
                        s["images"].length > 0 &&
                        s["images"][0].toString().contains("http"))
                    ? Image.network(
                        s["images"][0],
                        fit: BoxFit.cover,
                      )
                    : const Icon(Icons.image, size: 32, color: Colors.grey),
              ),
            ),

            const SizedBox(width: 14),

            // INFO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF285E6E)),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    cat,
                    style: const TextStyle(
                        color: Colors.teal, fontWeight: FontWeight.w500),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      const Icon(Icons.attach_money,
                          size: 16, color: Colors.grey),
                      Text("$price $currency",
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 10),
                      const Icon(Icons.star,
                          size: 16, color: Colors.amber),
                      Text(rating.toStringAsFixed(1)),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // EXPERT
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExpertDetailPage(expert: expert),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: expertImg.isNotEmpty
                              ? NetworkImage(expertImg)
                              : null,
                          child: expertImg.isEmpty
                              ? const Icon(Icons.person, size: 18)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            expertName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  /* ------------------------------ BUILD UI ------------------------------- */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        title: const Text(
          "Search Services",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 🔍 Search bar
            TextField(
              onChanged: (v) {
                query = v;
                _search();
              },
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: "Search services...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
              ),
            ),

            const SizedBox(height: 18),

            // 🔘 Categories Row
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: categories.map((c) {
                  final selected = category == c;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      selectedColor: const Color(0xFF62C6D9),
                      labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black),
                      onSelected: (_) {
                        setState(() => category = c);
                        _search();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 10),

            // SORT
            Align(
              alignment: Alignment.centerRight,
              child: DropdownButton<String>(
                value: sort,
                items: const [
                  DropdownMenuItem(
                      value: "rating_desc", child: Text("Top Rated")),
                  DropdownMenuItem(
                      value: "price_asc", child: Text("Lowest Price")),
                  DropdownMenuItem(
                      value: "price_desc", child: Text("Highest Price")),
                  DropdownMenuItem(
                      value: "name_az", child: Text("Name A-Z")),
                  DropdownMenuItem(
                      value: "name_za", child: Text("Name Z-A")),
                ],
                onChanged: (v) {
                  sort = v!;
                  _search();
                },
              ),
            ),

            const SizedBox(height: 10),

            // RESULTS
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                      ? const Center(
                          child: Text("No results found",
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) =>
                              _buildServiceCard(results[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
