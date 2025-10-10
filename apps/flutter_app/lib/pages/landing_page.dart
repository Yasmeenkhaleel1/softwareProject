import 'package:flutter/material.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  bool isLoggedIn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE5B4),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5BB19F),
        elevation: 0,
        titleSpacing: 10,
        title: Row(
          children: [
            Image.asset('assets/images/treasure_icon.png', height: 26),
            const SizedBox(width: 6),
            const Text(
              "Lost Treasures",
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 18,
                  letterSpacing: 1.2),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text("Home", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {},
            child: const Text("About", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {},
            child: const Text("Services", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {},
            child: const Text("Contact", style: TextStyle(color: Colors.white)),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.black, size: 28),
            color: Colors.white,
            onSelected: (value) {
              if (value == 'login') {
                Navigator.pushNamed(context, '/login');
              } else if (value == 'signup') {
                Navigator.pushNamed(context, '/signup');
              } else if (value == 'profile') {
                // لاحقاً صفحة profile
              } else if (value == 'logout') {
                setState(() => isLoggedIn = false);
              }
            },
            itemBuilder: (context) {
              if (!isLoggedIn) {
                return [
                  const PopupMenuItem(value: 'login', child: Text('Log In')),
                  const PopupMenuItem(value: 'signup', child: Text('Sign Up')),
                ];
              } else {
                return [
                  const PopupMenuItem(value: 'profile', child: Text('Profile')),
                  const PopupMenuItem(value: 'logout', child: Text('Log Out')),
                ];
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
            child: Column(
              children: [
                const Text(
                  "DISCOVER THE HIDDEN HUMAN TREASURES AROUND YOU",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E2A38),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "Connecting skilled and experienced individuals with those who seek their expertise.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 15,
                  runSpacing: 10,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5D491),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: const Text(
                        "Explore Experts",
                        style: TextStyle(
                            fontSize: 15, color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3C82F6),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: const Text(
                        "Log In",
                        style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/signup');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      ),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
