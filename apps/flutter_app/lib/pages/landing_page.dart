import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/auth_state.dart';
import '../widgets/custom_appbar.dart';
import '../pages/profile_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: CustomAppBar(
        isLoggedIn: authState.isAuthenticated,
        onMenuSelected: (value) {
          switch (value) {
            case 'login':
              Navigator.pushNamed(context, '/login');
              break;
            case 'signup':
              Navigator.pushNamed(context, '/signup');
              break;
            case 'logout':
              authState.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              break;
            case 'profile':
              switch (authState.userRole) {
                case 'customer':
                  Navigator.push(context, MaterialPageRoute(builder: (_) =>  CustomerProfilePage()));
                  break;
               /* case 'specialist':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SpecialistProfilePage()));
                  break;
                case 'admin':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardPage()));
                  break;*/
              }
              break;
          }
        },
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left Text & Buttons
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DISCOVER THE HIDDEN HUMAN TREASURES AROUND YOU",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E2A38), height: 1.3),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "Connecting skilled and experienced individuals with those who seek their expertise.",
                      style: TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 40),
                    Wrap(
                      spacing: 15,
                      runSpacing: 10,
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF62C6D9),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text("Explore Experts", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                        if (!authState.isAuthenticated) ...[
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C6D9),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Log In", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pushNamed(context, '/signup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF62C6D9),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text("Sign Up", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 50),

              // Right Image
              Expanded(
                flex: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: const Color(0xFF62C6D9).withOpacity(0.5), blurRadius: 40, spreadRadius: 8)],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: Image.asset('assets/images/landing1.png', fit: BoxFit.cover),
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
