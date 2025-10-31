import 'package:flutter/material.dart';

class ExpertDetailPage extends StatelessWidget {
  final Map<String, dynamic> expert;

  const ExpertDetailPage({super.key, required this.expert});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(expert['name']),
        backgroundColor: const Color(0xFF62C6D9),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              expert['name'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "Specialty: ${expert['specialty'] ?? 'N/A'}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              "Rating: ${expert['rating'] ?? 0}",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            const Text(
              "Services Offered",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  ListTile(
                    title: const Text("Service 1"),
                    subtitle: const Text("Description of Service 1"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Booking successful!")),
                        );
                      },
                      child: const Text("Book"),
                    ),
                  ),
                  ListTile(
                    title: const Text("Service 2"),
                    subtitle: const Text("Description of Service 2"),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Booking successful!")),
                        );
                      },
                      child: const Text("Book"),
                    ),
                  ),
                  // ممكن تجيب الخدمات الحقيقية من الباك لاحقاً
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}