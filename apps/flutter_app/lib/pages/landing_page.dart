import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

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
  static String get baseUrl => ApiConfig.baseUrl;

  bool loading = false;
  String? role;

  // ====== NEW: scroll to sections ======
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _aboutKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUserRole();
    }
  }

  Future<void> _fetchUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      if (token.isEmpty) return;

      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => role = data['user']['role']);
      }
    } catch (_) {
      // ignore
    }
  }

  void _showSnack(String msg, {Color color = Colors.orangeAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  void _handleAdminDashboard() {
    Navigator.pushNamed(context, '/admin_dashboard_page');
  }

  Future<void> _handleExpertDashboard() async {
    setState(() => loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$baseUrl/api/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final approved = data['user']['isApproved'] == true;

        if (approved) {
          Navigator.pushNamed(context, '/expert_dashboard_page');
        } else {
          _showSnack('⏳ Your profile is still under review by the admin.');
        }
      } else {
        _showSnack('❌ Failed to fetch your status.');
      }
    } catch (e) {
      _showSnack('⚠️ Error: $e');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');

    setState(() {
      loading = false;
      role = null;
    });

    widget.onLogout();

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/landing_page',
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoggedIn && role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return _LandingWebLayout(
            scrollController: _scrollController,
            homeKey: _homeKey,
            aboutKey: _aboutKey,
            contactKey: _contactKey,

            onNavHome: () => _scrollTo(_homeKey),
            onNavAbout: () => _scrollTo(_aboutKey),
            onNavContact: () => _scrollTo(_contactKey),

            isLoggedIn: widget.isLoggedIn,
            role: role,
            loading: loading,
            onLogout: _handleLogout,
            onLogin: () => Navigator.pushNamed(context, '/login_page'),
            onSignup: () => Navigator.pushNamed(context, '/signup_page'),
            onCustomerDashboard: () =>
                Navigator.pushNamed(context, '/customer_dashboard_page'),
            onExpertDashboard: _handleExpertDashboard,
            onAdminDashboard: _handleAdminDashboard,
          );
        } else {
          return _LandingMobileLayout(
            scrollController: _scrollController,
            homeKey: _homeKey,
            aboutKey: _aboutKey,
            contactKey: _contactKey,

            onNavHome: () => _scrollTo(_homeKey),
            onNavAbout: () => _scrollTo(_aboutKey),
            onNavContact: () => _scrollTo(_contactKey),

            isLoggedIn: widget.isLoggedIn,
            role: role,
            loading: loading,
            onLogout: _handleLogout,
            onLogin: () => Navigator.pushNamed(context, '/login_page'),
            onSignup: () => Navigator.pushNamed(context, '/signup_page'),
            onCustomerDashboard: () =>
                Navigator.pushNamed(context, '/customer_dashboard_page'),
            onExpertDashboard: _handleExpertDashboard,
            onAdminDashboard: _handleAdminDashboard,
          );
        }
      },
    );
  }
}

class _LandingWebLayout extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final bool loading;
  final VoidCallback onLogout;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onCustomerDashboard;
  final VoidCallback onExpertDashboard;
  final VoidCallback onAdminDashboard;

  // NEW
  final ScrollController scrollController;
  final GlobalKey homeKey;
  final GlobalKey aboutKey;
  final GlobalKey contactKey;

  final VoidCallback onNavHome;
  final VoidCallback onNavAbout;
  final VoidCallback onNavContact;

  const _LandingWebLayout({
    required this.isLoggedIn,
    required this.role,
    required this.loading,
    required this.onLogout,
    required this.onLogin,
    required this.onSignup,
    required this.onCustomerDashboard,
    required this.onExpertDashboard,
    required this.onAdminDashboard,

    required this.scrollController,
    required this.homeKey,
    required this.aboutKey,
    required this.contactKey,
    required this.onNavHome,
    required this.onNavAbout,
    required this.onNavContact,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/treasure_icon.png', height: 30),
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
            onPressed: onNavHome,
            child: const Text(
              "Home",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: onNavAbout,
            child: const Text(
              "About",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: onNavContact,
            child: const Text(
              "Contact Us",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 20),

          // ✅ حذفنا Login من الهيدر (وكمان Logout)
          // إذا بدك زر "Get Started" هون خبريني.
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: scrollController,
              child: Column(
                children: [
                  // ===== HERO =====
                  Container(
                    key: homeKey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 50),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _LandingMainTextAndButtons(
                              isLoggedIn: isLoggedIn,
                              role: role,
                              onSignup: onSignup,
                              onLogin: onLogin,
                              onCustomerDashboard: onCustomerDashboard,
                              onExpertDashboard: onExpertDashboard,
                              onAdminDashboard: onAdminDashboard,
                              onLogout: onLogout,
                            ),
                          ),
                          const SizedBox(width: 50),
                          const Expanded(
                            flex: 1,
                            child: _LandingImage(),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ===== ABOUT =====
                  _AboutSection(key: aboutKey),

                  // ===== CONTACT =====
                  _ContactSection(key: contactKey),

                  const SizedBox(height: 30),
                  const _Footer(),
                ],
              ),
            ),
    );
  }
}

class _LandingMobileLayout extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final bool loading;
  final VoidCallback onLogout;
  final VoidCallback onLogin;
  final VoidCallback onSignup;
  final VoidCallback onCustomerDashboard;
  final VoidCallback onExpertDashboard;
  final VoidCallback onAdminDashboard;

  // NEW
  final ScrollController scrollController;
  final GlobalKey homeKey;
  final GlobalKey aboutKey;
  final GlobalKey contactKey;

  final VoidCallback onNavHome;
  final VoidCallback onNavAbout;
  final VoidCallback onNavContact;

  const _LandingMobileLayout({
    required this.isLoggedIn,
    required this.role,
    required this.loading,
    required this.onLogout,
    required this.onLogin,
    required this.onSignup,
    required this.onCustomerDashboard,
    required this.onExpertDashboard,
    required this.onAdminDashboard,

    required this.scrollController,
    required this.homeKey,
    required this.aboutKey,
    required this.contactKey,
    required this.onNavHome,
    required this.onNavAbout,
    required this.onNavContact,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/treasure_icon.png', height: 26),
            const SizedBox(width: 6),
            const Text(
              "LOST TREASURES",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
        // ✅ حذفنا Login من الهيدر
        actions: const [],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mobile mini nav (احترافي بدل ما يكون فاضي)
                  Row(
                    children: [
                      TextButton(onPressed: onNavHome, child: const Text("Home")),
                      TextButton(onPressed: onNavAbout, child: const Text("About")),
                      TextButton(
                          onPressed: onNavContact,
                          child: const Text("Contact")),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Container(
                    key: homeKey,
                    child: _LandingMainTextAndButtons(
                      isLoggedIn: isLoggedIn,
                      role: role,
                      onSignup: onSignup,
                      onLogin: onLogin,
                      onCustomerDashboard: onCustomerDashboard,
                      onExpertDashboard: onExpertDashboard,
                      onAdminDashboard: onAdminDashboard,
                      onLogout: onLogout,
                      isMobile: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _LandingImage(),
                  const SizedBox(height: 28),

                  _AboutSection(key: aboutKey),
                  const SizedBox(height: 24),
                  _ContactSection(key: contactKey),

                  const SizedBox(height: 24),
                  const _Footer(),
                ],
              ),
            ),
    );
  }
}

class _LandingMainTextAndButtons extends StatelessWidget {
  final bool isLoggedIn;
  final String? role;
  final bool isMobile;
  final VoidCallback onSignup;
  final VoidCallback onLogin;
  final VoidCallback onCustomerDashboard;
  final VoidCallback onExpertDashboard;
  final VoidCallback onAdminDashboard;
  final VoidCallback onLogout;

  const _LandingMainTextAndButtons({
    required this.isLoggedIn,
    required this.role,
    required this.onSignup,
    required this.onLogin,
    required this.onCustomerDashboard,
    required this.onExpertDashboard,
    required this.onAdminDashboard,
    required this.onLogout,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment:
          isMobile ? MainAxisAlignment.start : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "DISCOVER THE HIDDEN HUMAN TREASURES AROUND YOU",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E2A38),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          "Connecting skilled and experienced individuals with those who seek their expertise.",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (!isLoggedIn) ...[
              _LandingButton(
                label: "Sign Up",
                color: const Color(0xFF62C6D9),
                onPressed: onSignup,
              ),
              _LandingButton(
                label: "Log In",
                color: const Color(0xFF62C6D9),
                onPressed: onLogin,
              ),
            ] else if (role == "EXPERT") ...[
              _LandingButton(
                label: "Expert Dashboard",
                color: Colors.green,
                onPressed: onExpertDashboard,
              ),
              _LandingButton(
                label: "Logout",
                color: Colors.redAccent,
                onPressed: onLogout,
              ),
            ] else if (role == "CUSTOMER") ...[
              _LandingButton(
                label: "Customer Dashboard",
                color: const Color(0xFF62C6D9),
                onPressed: onCustomerDashboard,
              ),
              _LandingButton(
                label: "Logout",
                color: Colors.redAccent,
                onPressed: onLogout,
              ),
            ] else if (role == "ADMIN") ...[
              _LandingButton(
                label: "Admin Dashboard",
                color: Colors.orangeAccent,
                onPressed: onAdminDashboard,
              ),
              _LandingButton(
                label: "Logout",
                color: Colors.redAccent,
                onPressed: onLogout,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LandingImage extends StatelessWidget {
  const _LandingImage();

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

// ===================
// NEW: About Section
// ===================
class _AboutSection extends StatelessWidget {
  const _AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7FBFD),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "About Lost Treasures",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A38),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Lost Treasures is a marketplace that connects customers with verified experts across multiple categories. "
            "Find the right expert, book securely, and get results faster.",
            style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 26),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _FeatureCard(
                title: "Verified Experts",
                subtitle: "Quality-first profiles reviewed by admins.",
                icon: Icons.verified,
              ),
              _FeatureCard(
                title: "Easy Booking",
                subtitle: "Book a session in a few clicks.",
                icon: Icons.event_available,
              ),
              _FeatureCard(
                title: "Secure Payments",
                subtitle: "Trusted checkout and transparent pricing.",
                icon: Icons.lock,
              ),
              _FeatureCard(
                title: "Smart Matching",
                subtitle: "Recommendations based on your interests.",
                icon: Icons.auto_awesome,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =====================
// NEW: Contact Section
// =====================
class _ContactSection extends StatelessWidget {
  const _ContactSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Contact Us",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2A38),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Have a question or need help? Reach out and we’ll get back to you.",
            style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.6),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _InfoChip(icon: Icons.email, text: "support@losttreasures.com"),
              _InfoChip(icon: Icons.phone, text: "+970 000 000 000"),
              _InfoChip(icon: Icons.location_on, text: "Palestine"),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Color(0xFFE6EEF2)),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                )
              ],
            ),
         
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6EEF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF62C6D9).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF287E8D)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 12, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3FBFD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE6EEF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF287E8D)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Color(0xFF1E2A38))),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      color: const Color(0xFF62C6D9),
      child: const Text(
        "© 2026 Lost Treasures. All rights reserved.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _LandingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _LandingButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
