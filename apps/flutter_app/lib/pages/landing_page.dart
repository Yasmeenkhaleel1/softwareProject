import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
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

  void handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'login':
        Navigator.pushNamed(context, '/login');
        break;
      case 'signup':
        Navigator.pushNamed(context, '/signup');
        break;
      case 'logout':
        onLogout();
        break;
      case 'home':
        Navigator.pushNamed(context, '/');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 🔹 نفس ستايل الصفحة الأولى
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9), // 🔹 لون أزرق سماوي
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/treasure_icon.png',
              height: 30,
            ),
            const SizedBox(width: 8),
            const Text(
              "LOST TREASURES",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => handleMenuSelection(context, 'home'),
            child: const Text("Home", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => handleMenuSelection(context, 'signup'),
            child: const Text("About", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => handleMenuSelection(context, 'signup'),
            child: const Text("Services", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => handleMenuSelection(context, 'signup'),
            child: const Text("Contact", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          if (isLoggedIn)
            TextButton(
              onPressed: () => handleMenuSelection(context, 'logout'),
              child: const Text("Logout",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          else
            TextButton(
              onPressed: () => handleMenuSelection(context, 'login'),
              child: const Text("Login",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 20),
        ],
      ),

      // 🔹 المحتوى الرئيسي
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🧾 النصوص والأزرار (اليسار)
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DISCOVER THE HIDDEN HUMAN TREASURES AROUND YOU",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E2A38),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Connecting skilled and experienced individuals with those who seek their expertise.",
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // 🔹 الأزرار — تتغير حسب حالة المستخدم
                    Wrap(
                      spacing: 15,
                      runSpacing: 10,
                      children: [
                        if (!isLoggedIn) ...[
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C6D9),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Sign Up",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C6D9),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Log In",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/expert_dashboard');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Go to Dashboard",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: onLogout,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Logout",
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 50),

              // 🖼️ الصورة (اليمين)
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF62C6D9).withOpacity(0.5),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset(
                      'assets/images/landing1.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
