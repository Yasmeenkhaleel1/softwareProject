import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 🔑 مهم: تم ضبطه للعمل على متصفح الويب (localhost)
  // إذا كنت تختبر على محاكي أندرويد، قم بتغييره إلى: "http://10.0.2.2:5000/api"
  static const String baseUrl = "http://localhost:5000/api"; 

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  // 🔄 دالة جديدة: التحقق من رمز OTP
  static Future<Map<String, dynamic>> verifyOTP(String email, String otpCode) async {
    final res = await http.post(
      Uri.parse('$baseUrl/verify-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otpCode': otpCode}),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode == 200 && body['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', body['token']);
      
      // حفظ الدور (Role) لتسجيل الدخول التلقائي
      if (body['user'] != null && body['user']['role'] != null) {
          await prefs.setString('userRole', body['user']['role']);
      }
    }

    return body;
  }
  
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final body = jsonDecode(res.body);

    if (res.statusCode == 200 && body['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', body['token']);
      
      // حفظ الدور (Role) عند تسجيل الدخول
      if (body['user'] != null && body['user']['role'] != null) {
          await prefs.setString('userRole', body['user']['role']);
      }
    }

    return body;
  }

  static Future<Map<String, dynamic>> changePassword(String oldPass, String newPass) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'oldPassword': oldPass,
        'newPassword': newPass,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userRole'); 
  }
}