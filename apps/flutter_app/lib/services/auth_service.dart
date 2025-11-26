//lib/sevices/auth_service
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:5000'; // ← غيّري عند النشر

  // =============================
  // REGISTER
  // =============================
  Future<String?> register({
    required String email,
    required String password,
    required int age,
    required String gender,
    required String role,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'age': age,
          'gender': gender,
          'role': role,
        }),
      );

      if (res.statusCode == 201) {
        return null; // ✅ تم التسجيل بنجاح
      } else {
        final body = jsonDecode(res.body);
        return body['message'] ?? 'Registration failed';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // =============================
  // LOGIN
  // =============================
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();

        // ✅ نحفظ فقط ما نحتاجه فعلاً
        await prefs.setString('token', data['token']);
        await prefs.setString('role', data['user']['role']);
        await prefs.setString('email', data['user']['email']);

        return {'error': null, 'user': data['user']};
      } else {
        final body = jsonDecode(res.body);
        return {'error': body['message'] ?? 'Login failed', 'user': null};
      }
    } catch (e) {
      return {'error': 'Error: $e', 'user': null};
    }
  }

  // =============================
  // LOGOUT
  // =============================
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('role');
    await prefs.remove('email');
  }

  // =============================
  // CHECK LOGIN STATUS
  // =============================
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // =============================
  // RESEND VERIFICATION EMAIL (OTP)
  // =============================
  Future<String?> resendVerification(String email) async {
    final uri = Uri.parse('$baseUrl/auth/resend-code');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (res.statusCode == 200) {
        return null; // ✅ تم الإرسال بنجاح
      } else {
        final body = jsonDecode(res.body);
        return body['message'] ?? 'Failed to resend verification';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // =============================
  // VERIFY EMAIL CODE (OTP)
  // =============================
  Future<String?> verifyCode(String email, String code) async {
    final uri = Uri.parse('$baseUrl/auth/verify-code');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (res.statusCode == 200) {
        return null; // ✅ تم التحقق بنجاح
      } else {
        final body = jsonDecode(res.body);
        return body['message'] ?? 'Invalid or expired code';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  // =============================
  // CHANGE PASSWORD
  // =============================
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');

    if (email == null) {
      return {'message': 'No email found. Please log in again.'};
    }

    final uri = Uri.parse('$baseUrl/auth/change-password');

    try {
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(res.body);
      return {'message': data['message'] ?? 'Unknown response'};
    } catch (e) {
      return {'message': 'Error: $e'};
    }
  }
}
