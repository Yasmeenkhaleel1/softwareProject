import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const baseUrl = "http://localhost:5000";
  bool loading = false;
  String? role;

  @override
  void initState() {
    super.initState();
    if (widget.isLoggedIn) {
      _fetchUserRole();
    }
  }

  // ✅ جلب الدور الحقيقي من السيرفر
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
    } catch (e) {
      print('❌ Error fetching role: $e');
    }
  }

  void _showSnack(String msg, {Color color = Colors.orangeAccent}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }
// ✅ انتقال الأدمن للوحة التحكم
void _handleAdminDashboard() {
  Navigator.pushNamed(context, '/admin_dashboard_page');
}
  // ✅ فحص موافقة الأدمن للخبير عند الضغط على Dashboard
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

  @override
  Widget build(BuildContext context) {
    // ✅ أثناء تحميل الدور من السيرفر
    if (widget.isLoggedIn && role == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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

        // ✅ تمت إضافة الأزرار هنا فقط (بدون حركة أو أقسام)
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              "Home",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "About",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "Contact Us",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
if (widget.isLoggedIn)
  TextButton(
    onPressed: () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token'); // 🧹 حذف التوكن

      // ✅ إعادة الحالة
      setState(() {
        loading = false;
        role = null;
      });

      widget.onLogout(); // تحديث حالة التطبيق

      if (context.mounted) {
        // ✅ إعادة تحميل صفحة اللاندنغ بشكل فوري
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/landing',
          (Route<dynamic> route) => false,
        );
      }
    },
    child: const Text(
      "Logout",
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
  )


          else
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/login_page'),
              child: const Text(
                "Login",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(width: 20),
        ],
      ),

      // 🔹 المحتوى الرئيسي كما هو بدون تغيير
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Row(
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

                          // ✅ الأزرار الديناميكية (حسب الدور)
                          Wrap(
                            spacing: 15,
                            runSpacing: 10,
                            children: [
                              // 🔹 المستخدم غير المسجل
                              if (!widget.isLoggedIn) ...[
                                _buildButton(
                                  label: "Sign Up",
                                  color: const Color(0xFF62C6D9),
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/signup_page'),
                                ),
                                _buildButton(
                                  label: "Log In",
                                  color: const Color(0xFF62C6D9),
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/login_page'),
                                ),
                              ]

                              // 🧠 الخبير
                              else if (role == "EXPERT") ...[
                                _buildButton(
                                  label: "Expert Dashboard",
                                  color: Colors.green,
                                  onPressed: _handleExpertDashboard,
                                ),
                                _buildButton(
                                  label: "Logout",
                                  color: Colors.redAccent,
                                  onPressed: widget.onLogout,
                                ),
                              ]

                              // 👤 الكستمر
                              else if (role == "CUSTOMER") ...[
                                _buildButton(
                                  label: "Customer Dashboard",
                                  color: const Color(0xFF62C6D9),
                                  onPressed: () => Navigator.pushNamed(
                                      context, '/customer_dashboard_page'),
                                ),
                                _buildButton(
                                  label: "Logout",
                                  color: Colors.redAccent,
                                  onPressed: widget.onLogout,
                                ),
                              ]

                              // 🛡️ الأدمن
                              else if (role == "ADMIN") ...[
                              _buildButton(
                               label: "Admin Dashboard",
                               color: Colors.orangeAccent,
                               onPressed: _handleAdminDashboard,
                             ),
                              _buildButton(
                               label: "Logout",
                               color: Colors.redAccent,
                               onPressed: widget.onLogout,
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

  // 🔹 دالة مساعدة لبناء الأزرار
  Widget _buildButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding:
            const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
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
