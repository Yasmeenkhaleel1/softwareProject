import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatBotWidget extends StatefulWidget {
  const ChatBotWidget({super.key});

  @override
  State<ChatBotWidget> createState() => _ChatBotWidgetState();
}

class _ChatBotWidgetState extends State<ChatBotWidget> {
  final TextEditingController _controller = TextEditingController();
final ScrollController _chipScrollController = ScrollController();
  final List<Map<String, String>> messages = [
    {"sender": "bot", "text": "Hello! 👋 How can I help you today?"},
  ];

  final List<String> suggestedQuestions = [
    "How can I book a service?",
    "How to contact an expert?",
    "What payment methods do you support?",
    "How do I edit my profile?",
  ];

  // ================== SEND MESSAGE TO BACKEND ==================
void sendMessage(String text) async {
  if (text.trim().isEmpty) return;

  setState(() {
    messages.add({"sender": "user", "text": text});
  });

  _controller.clear();

  try {
    final res = await http.post(
  Uri.parse("http://localhost:5000/api/chatbot"),
  headers: {
    "Content-Type": "application/json",
  }, // بدون Authorization نهائيًا
  body: jsonEncode({"message": text}),
);


    final data = jsonDecode(res.body);

    setState(() {
      messages.add({
        "sender": "bot",
        "text": data["reply"] ?? "No reply",
      });
    });
  } catch (e) {
    setState(() {
      messages.add({
        "sender": "bot",
        "text": "Error connecting to server.",
      });
    });
  }
}
 // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // top drag line
          Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 15),

          const Text(
            "AI Assistant 🤖",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D5C68),
            ),
          ),

          const SizedBox(height: 10),

          // ===================== QUICK SUGGESTIONS =====================
 // ===================== QUICK SUGGESTIONS =====================



SizedBox(
  height: 48,
  child: Row(
    children: [
      // ◀ LEFT BUTTON
      IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF62C6D9)),
        onPressed: () {
          _chipScrollController.animateTo(
            _chipScrollController.offset - 150,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
      ),

      // HORIZONTAL SCROLL
      Expanded(
        child: SingleChildScrollView(
          controller: _chipScrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final q in suggestedQuestions)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => sendMessage(q),
                    child: Chip(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      backgroundColor: const Color(0xFF62C6D9),
                      label: Text(
                        q,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      // ▶ RIGHT BUTTON
      IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 18, color: Color(0xFF62C6D9)),
        onPressed: () {
          _chipScrollController.animateTo(
            _chipScrollController.offset + 150,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        },
      ),
    ],
  ),
),

          // ===================== CHAT MESSAGES =====================
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final msg = messages[i];
                final isUser = msg["sender"] == "user";

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          isUser ? const Color(0xFF62C6D9) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg["text"]!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ===================== INPUT FIELD =====================
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Ask me anything...",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              IconButton(
                icon: const Icon(Icons.send, color: Color(0xFF62C6D9)),
                onPressed: () => sendMessage(_controller.text.trim()),
              ),
            ],
          )
        ],
      ),
    );
  }
}
