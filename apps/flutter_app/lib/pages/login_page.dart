import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart';
import '../models/auth_state.dart';
import 'signup_page.dart'; // للتنقل إلى صفحة التسجيل
import 'dashboard_page.dart'; // للتنقل بعد تسجيل الدخول الناجح

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🚀 وظيفة تسجيل الدخول الفعلية
  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        // 📞 استدعاء API الدخول
        final res = await ApiService.login(
          _emailController.text, 
          _passwordController.text,
        );
        
        if (res['token'] != null) {
          // 🔑 الدخول ناجح: تحديث حالة المصادقة
          final token = res['token'];
          // نفترض أن جسم الاستجابة يحتوي على دور المستخدم تحت مفتاح 'user'
          final role = res['user']['role']; 

          // استخدام Provider لتحديث حالة التطبيق
          Provider.of<AuthState>(context, listen: false).login(token, role); 
          
          _showSnackBar('Login successful!', Colors.green);

          // الانتقال إلى لوحة التحكم (Dashboard) ومسح جميع الصفحات السابقة
          Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false); 
        } else {
          // فشل الدخول
          final message = res['message'] ?? 'Login failed. Check your credentials.';
          _showSnackBar(message, Colors.red);
        }
      } catch (e) {
        // خطأ في الاتصال بالخادم
        _showSnackBar('An error occurred. Check server connection or address.', Colors.red);
        print('Login Error: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // 💬 وظيفة لإظهار رسائل التنبيه
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    // تحديد عرض الحاوية للويب/الديسكتوب
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: isWeb ? 400 : double.infinity,
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // 📧 حقل الإيميل
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email, color: Color(0xFF62C6D9)),
                    ),
                    validator: (value) {
                      if (value == null || !value.contains('@') || value.isEmpty) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 🔒 حقل كلمة المرور
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF62C6D9)),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  
                  // 🔗 رابط نسيت كلمة المرور
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // 🚧 يحتاج إلى صفحة 'Forgot Password' في المسارات
                        Navigator.pushNamed(context, '/forgot-password'); 
                      },
                      child: const Text("Forgot Password?", style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ➡️ زر الدخول
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login, // منع النقر أثناء التحميل
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF62C6D9),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Text(
                            'Log In', 
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)
                          ),
                  ),
                  const SizedBox(height: 15),

                  // 🔗 رابط للتسجيل
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
                    child: const Text(
                      "Don't have an account? Sign Up", 
                      style: TextStyle(color: Color(0xFF62C6D9), fontWeight: FontWeight.w600)
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}