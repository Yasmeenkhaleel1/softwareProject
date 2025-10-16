import 'package:flutter/material.dart';
// تم إزالة استيراد lottie.dart

// 🔑 ملاحظة هامة: يجب أن يكون اسم الكلاس هنا هو ForgotPasswordPage
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isEmailSent = false;

  void _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // ⚠️ هنا يجب استدعاء API لإرسال رابط إعادة التعيين (مثلاً: POST /api/forgot-password)
      // حاليا هي محاكاة للتحميل
      await Future.delayed(const Duration(seconds: 2)); 

      setState(() {
        _isLoading = false;
        _isEmailSent = true;
      });
      
      _showSnackBar('Reset link sent to your email!', Colors.green);
    }
  }
  
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
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
                  // 🎨 استخدام أيقونة ثابتة بدلاً من Lottie
                  const Center(
                    child: Icon(Icons.lock_reset, size: 80, color: Color(0xFF62C6D9)),
                  ),
                  const SizedBox(height: 30),

                  Text(
                    _isEmailSent 
                    ? 'Please check your email (${_emailController.text}) for instructions to reset your password.'
                    : 'Enter the email address associated with your account to receive a password reset link.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  const SizedBox(height: 30),

                  if (!_isEmailSent) ...[
                    // 📧 حقل الإيميل
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email, color: Color(0xFF62C6D9)),
                      ),
                      validator: (value) => !value!.contains('@') ? 'Enter a valid email address' : null,
                    ),
                    const SizedBox(height: 30),

                    // ➡️ زر الإرسال
                    ElevatedButton(
                      onPressed: _isLoading ? null : _sendResetLink,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF62C6D9),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      // 🔄 استخدام CircularProgressIndicator بدلاً من Lottie
                      child: _isLoading
                          ? const SizedBox(
                              width: 20, 
                              height: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : const Text('Send Reset Link', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ],

                  if (_isEmailSent) 
                    TextButton(
                      onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text('Return to Log In', style: TextStyle(color: Color(0xFF62C6D9))),
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