import 'package:flutter/material.dart';

class CustomerMessagesPage extends StatelessWidget {
  const CustomerMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: const Color(0xFF62C6D9),
      ),
      body: const Center(
        child: Text(
          "Here we'll build chat between customer and expert.\n"
          "One-to-one sessions & Zoom links later.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
