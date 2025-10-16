import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/api_service.dart'; 
import '../models/auth_state.dart'; 
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  String? _selectedGender; 
  String _selectedRole = 'customer'; 
  
  bool _isLoading = false;
  bool _isOTPSent = false;
  
  final List<String> roles = ['customer', 'specialist', 'admin']; 
  
  // 🔑 لتخزين الإيميل الذي تم إرسال الرمز إليه
  String _registeredEmail = ''; 

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _ageController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _signUp() async {
    if (!_formKey.currentState!.validate() || _selectedGender == null) {
      _showSnackBar('Please fill all required fields correctly.', Colors.red);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Passwords do not match.', Colors.red);
      return;
    }
    
    setState(() => _isLoading = true);
    
    final userData = {
      'name': _nameController.text,
      'email': _emailController.text,
      'password': _passwordController.text,
      'age': int.tryParse(_ageController.text) ?? 0,
      'gender': _selectedGender,
      'role': _selectedRole, 
    };

    try {
      final res = await ApiService.signup(userData);
      
      if (res['message'].startsWith('User registered successfully')) {
        _showSnackBar('Registration successful! Check your email for verification.', Colors.green);
        setState(() {
            _registeredEmail = _emailController.text; // 🔑 حفظ الإيميل
            _isOTPSent = true; 
        });
      } else {
        _showSnackBar(res['message'] ?? 'Registration failed', Colors.red);
      }
    } catch (e) {
      _showSnackBar('An error occurred. Check server connection or address.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _verifyOTP() async {
    if (_otpController.text.length != 6) {
        _showSnackBar('Please enter a 6-digit code.', Colors.red);
        return;
    }
    
    setState(() => _isLoading = true);

    try {
        final res = await ApiService.verifyOTP(_registeredEmail, _otpController.text);

        if (res['token'] != null) {
            // التحقق ناجح: تسجيل الدخول التلقائي عبر Provider
            final role = res['user'] != null ? res['user']['role'] : 'customer';
            Provider.of<AuthState>(context, listen: false).login(res['token'], role);

            _showSnackBar('Email verified successfully! Logging in...', Colors.green);
            // الانتقال إلى الداشبورد
            Navigator.of(context).pushNamedAndRemoveUntil('/dashboard', (route) => false); 
        } else {
            _showSnackBar(res['message'] ?? 'Verification failed (Code Invalid/Expired)', Colors.red);
        }
    } catch (e) {
        _showSnackBar('An error occurred during verification.', Colors.red);
    } finally {
        setState(() => _isLoading = false);
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
        title: Text(_isOTPSent ? 'Verify Email' : 'Sign Up'),
        backgroundColor: const Color(0xFF62C6D9),
        elevation: 0,
      ),
      body: Center(
        child: Container(
          width: isWeb ? 450 : double.infinity, 
          padding: const EdgeInsets.all(32.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildIconHeader(_isOTPSent ? Icons.lock_open : Icons.person_add),
                  const SizedBox(height: 30),

                  if (!_isOTPSent) ...[
                    // ... (حقول التسجيل: name, email, password, age, gender, role) ...
                    _buildTextField(_nameController, 'Full Name', Icons.person),
                    const SizedBox(height: 20),
                    _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),
                    _buildPasswordField(_passwordController, 'Password'),
                    const SizedBox(height: 20),
                    _buildPasswordField(_confirmPasswordController, 'Confirm Password', isConfirm: true, compareTo: _passwordController),
                    const SizedBox(height: 20),
                    _buildTextField(_ageController, 'Age', Icons.cake, 
                      keyboardType: TextInputType.number, 
                      validator: (v) { final age = int.tryParse(v!); if (age == null || age < 1) return 'Enter a valid age'; return null; }),
                    const SizedBox(height: 20),
                    _buildGenderDropdown(),
                    const SizedBox(height: 20),
                    _buildRoleDropdown(),
                    const SizedBox(height: 30),

                    _buildMainButton('Sign Up', _signUp, _isLoading),

                  ] else ...[
                    // 💡 شاشة التحقق من الرمز
                    const Text('Enter the 6-digit verification code sent to your email.', style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    _buildTextField(_otpController, 'Verification Code', Icons.verified_user, 
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.length != 6 ? 'Code must be 6 digits' : null),
                    const SizedBox(height: 30),
                    _buildMainButton('Verify Email', _verifyOTP, _isLoading),
                    const SizedBox(height: 15),
                    TextButton(onPressed: () { /* // يمكن إضافة منطق إعادة إرسال الرمز هنا */ }, child: const Text('Resend Code?', style: TextStyle(color: Colors.black54))),
                  ],

                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text("Already have an account? Log In", style: TextStyle(color: Color(0xFF62C6D9))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🏗️ الدوال المساعدة (بدون Lottie)
  
  Widget _buildIconHeader(IconData icon) {
    return Center(
      child: Icon(icon, size: 80, color: const Color(0xFF62C6D9)),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon, color: const Color(0xFF62C6D9))
      ),
      validator: validator ?? (value) => value!.isEmpty ? 'Please enter your $label' : null,
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, {bool isConfirm = false, TextEditingController? compareTo}) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock, color: Color(0xFF62C6D9))),
      validator: (value) {
        if (value!.length < 6) return 'Password must be at least 6 characters';
        if (isConfirm && value != compareTo!.text) return 'Passwords do not match';
        return null;
      },
    );
  }
  
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people, color: Color(0xFF62C6D9))),
      value: _selectedGender,
      items: ['male', 'female', 'other'].map((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()))).toList(),
      onChanged: (String? newValue) => setState(() => _selectedGender = newValue),
      validator: (value) => value == null ? 'Please select gender' : null,
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(labelText: 'I am a...', border: OutlineInputBorder(), prefixIcon: Icon(Icons.handshake, color: Color(0xFF62C6D9))),
      value: _selectedRole,
      items: roles.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value.toUpperCase()))).toList(),
      onChanged: (String? newValue) => setState(() => _selectedRole = newValue!),
    );
  }

  Widget _buildMainButton(String text, VoidCallback onPressed, bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF62C6D9),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
          : Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)),
    );
  }
}