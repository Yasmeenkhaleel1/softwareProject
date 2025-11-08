import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000/api"; // Android emulator localhost

  // ===================== Helpers خاصة بالتوكن =====================

  // حفظ التوكن
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  // جلب التوكن (لو احتجتيه لأي سبب)
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // تجهيز الهيدرز مع Authorization
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ===================== Auth =====================

  static Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(res.body);

    // ⬅️ مهم جداً: حفظ التوكن بعد تسجيل الدخول
    if (res.statusCode == 200 && body['token'] != null) {
      await _saveToken(body['token']);
    }

    return body;
  }

  static Future<Map<String, dynamic>> changePassword(
      String oldPass, String newPass) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/change-password'),
      headers: headers,
      body: jsonEncode({
        'oldPassword': oldPass,
        'newPassword': newPass,
      }),
    );
    return jsonDecode(res.body);
  }

  // ===================== Slots (الأوقات المتاحة) =====================
  // عدّلي الـ endpoint حسب اللي عندك بالباك إند

  static Future<Map<String, dynamic>> getExpertSlots(String expertId) async {
    final headers = await _authHeaders();

    final res = await http.get(
      Uri.parse('$baseUrl/availability/$expertId'),
      headers: headers,
    );

    return jsonDecode(res.body);
  }

  // ===================== Booking (عمل حجز) =====================
  // عدّلي الـ body والـ endpoint حسب مشروعك

  static Future<Map<String, dynamic>> createBooking(
      Map<String, dynamic> data) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/bookings'),
      headers: headers,
      body: jsonEncode(data),
    );

    return jsonDecode(res.body);
  }

  // ===================== Payment (الدفع) =====================

  static Future<Map<String, dynamic>> chargePayment(
      Map<String, dynamic> data) async {
    final headers = await _authHeaders();

    final res = await http.post(
      Uri.parse('$baseUrl/payments/charge'),
      headers: headers,
      body: jsonEncode(data),
    );

    return jsonDecode(res.body);
  }

  // ===================== Logout =====================

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
