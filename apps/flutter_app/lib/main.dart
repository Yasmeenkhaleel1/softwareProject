import 'package:flutter/material.dart';
import 'pages/landing_page.dart';

void main() {
  runApp(const LostTreasuresApp());
}

class LostTreasuresApp extends StatelessWidget {
  const LostTreasuresApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lost Treasures',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LandingPage(),
    );
  }
}
