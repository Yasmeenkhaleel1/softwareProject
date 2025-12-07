import 'package:flutter/material.dart';

class CustomerHelpPage extends StatelessWidget {
  const CustomerHelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Help & Support"),
        backgroundColor: const Color(0xFF62C6D9),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Report a problem or request a refund",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF285E6E),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Later رح نربطها مع booking معين ونعمل ticket حقيقية "
              "لـ Admin / Expert.",
            ),
            const SizedBox(height: 20),
            const TextField(
              maxLines: 5,
              decoration: InputDecoration(
                labelText: "Describe your issue",
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: null, // بعدين نربطها مع الـ backend
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF62C6D9),
                ),
                child: const Text(
                  "Submit",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
