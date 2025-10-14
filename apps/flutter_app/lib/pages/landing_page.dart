import 'package:flutter/material.dart';
import '../widgets/custom_appbar.dart';
import 'profile_page.dart';

class LandingPage extends StatefulWidget {
  final bool isLoggedIn;
  final void Function() onLogout;
  final String? userRole;
  final String? userId;

  const LandingPage({
    super.key,
    required this.isLoggedIn,
    required this.onLogout,
    this.userRole,
    this.userId,
  });

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  void handleMenuSelection(String value) {
    switch (value) {
      case 'login':
        Navigator.pushNamed(context, '/login');
        break;
      case 'signup':
        Navigator.pushNamed(context, '/signup');
        break;
      case 'profile':
        if (widget.userRole == 'customer') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(userId: widget.userId ?? ''),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This role has no profile page yet.")),
          );
        }
        break;
      case 'logout':
        widget.onLogout();
        break;
      case 'home':
        Navigator.pushNamed(context, '/');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE5B4),
      appBar: CustomAppBar(
        isLoggedIn: widget.isLoggedIn,
        onMenuSelected: handleMenuSelection,
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
                if (!widget.isLoggedIn)
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 15,
                    runSpacing: 10,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3C82F6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          "Log In",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  ElevatedButton(
                    onPressed: () => handleMenuSelection('profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 14,
                      ),
                    ),
                    child: const Text(
                      "Go to Profile",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
