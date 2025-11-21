// lib/pages/chatbot_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = "http://localhost:5000";

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;

  final List<String> suggestions = [
    "How can I book a session?",
    "How does the platform work?",
    "What payment methods are supported?",
    "How do I contact an expert?",
    "What are the available services?",
  ];

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _sending) return;

    setState(() {
      _messages.add({"role": "user", "content": text});
      _sending = true;
    });

    _controller.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString("token") ?? "";

      if (token.isEmpty) {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "Authentication error (no token found)."
          });
        });
        return;
      }

      final history = _messages
          .map((m) => {"role": m["role"], "content": m["content"]})
          .toList();

      final res = await http.post(
        Uri.parse("$baseUrl/api/chatbot"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"message": text, "history": history}),
      );

      if (res.statusCode == 200) {
        final reply = jsonDecode(res.body)["reply"] ?? "No reply";

        setState(() {
          _messages.add({"role": "assistant", "content": reply});
        });
      } else {
        setState(() {
          _messages.add({
            "role": "assistant",
            "content": "Error (${res.statusCode})"
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "assistant", "content": "Error: $e"});
      });
    }

    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF62C6D9);

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          bottomLeft: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(-3, 0)),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(16),
              child: const Text(
                "AI Chatbot Assistant",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            // SUGGESTIONS
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: suggestions
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          backgroundColor: primaryColor.withOpacity(0.15),
                          label: Text(s),
                          onPressed: () => _sendMessage(s),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            const Divider(),

            // MESSAGES
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  final isUser = m["role"] == "user";

                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: isUser ? primaryColor : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        m["content"]!,
                        style: TextStyle(
                          color: isUser ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // INPUT
            Container(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: _sendMessage,
                      decoration: InputDecoration(
                        hintText: "Ask something...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sending
                        ? null
                        : () => _sendMessage(_controller.text),
                    child: CircleAvatar(
                      backgroundColor: primaryColor,
                      child: _sending
                          ? const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
