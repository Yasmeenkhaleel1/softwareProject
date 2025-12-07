// lib/api/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 🔥 لأن المشروع يعمل فقط على الويب → نستخدم localhost دائماً
  static const String baseUrl = "http://localhost:5000/api";

  // 🔹 Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 🔹 Get stored userId
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

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

    if (res.statusCode == 200 && body['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', body['token']);
      if (body['user']?['_id'] != null) {
        await prefs.setString('userId', body['user']['_id']);
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
    await prefs.remove('userId');
  }

  // ---------- BOOKINGS ----------

  static Future<Map<String, dynamic>> createBookingPublic(Map<String, dynamic> data) async {
    final url = "$baseUrl/public/bookings";
    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createPublicBooking({
    required String expertId,
    required String serviceId,
    required String customerId,
    required String startAtIso,
    required String endAtIso,
    String timezone = "Asia/Hebron",
    String? note,
  }) async {
    final url = "$baseUrl/public/bookings";

    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "expertId": expertId,
        "serviceId": serviceId,
        "customerId": customerId,
        "startAt": startAtIso,
        "endAt": endAtIso,
        "timezone": timezone,
        "customerNote": note ?? "",
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode != 201) {
      throw Exception(body["message"] ?? body["error"] ?? "Failed to create booking");
    }
    return body;
  }

  // ---------- PAYMENTS ----------

  static Future<Map<String, dynamic>> createStripeIntent({
    required double amount,
    String currency = "USD",
    required String customerId,
    required String expertProfileId,
    required String serviceId,
    required String bookingId,
  }) async {
    final token = await getToken();
    final url = "$baseUrl/payments/intent";

    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "amount": amount,
        "currency": currency,
        "customer": customerId,
        "expertProfileId": expertProfileId,
        "service": serviceId,
        "booking": bookingId,
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body["error"] ?? "Failed to create payment intent");
    }
    return body;
  }

  static Future<void> confirmStripeIntent({
    required String paymentId,
    required String paymentIntentId,
    required String paymentMethodId,
  }) async {
    final token = await getToken();
    final url = "$baseUrl/payments/confirm";

    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "paymentId": paymentId,
        "paymentIntentId": paymentIntentId,
        "paymentMethod": paymentMethodId,
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body["error"] ?? "Stripe confirm failed");
    }
  }

    static Future<Map<String, dynamic>> getExpertEarningsSummary({
    DateTime? from,
    DateTime? to,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final buffer = StringBuffer("$baseUrl/expert/earnings/summary");

    final params = <String, String>{};
    if (from != null) params['from'] = from.toUtc().toIso8601String();
    if (to != null) params['to'] = to.toUtc().toIso8601String();

    if (params.isNotEmpty) {
      buffer.write("?");
      buffer.write(Uri(queryParameters: params).query);
    }

    final res = await http.get(
      Uri.parse(buffer.toString()),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final body = jsonDecode(res.body);

    if (res.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Failed to load earnings summary');
    }

    return body;
  }

  static Future<List<dynamic>> getExpertPayments({
    DateTime? from,
    DateTime? to,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final buffer = StringBuffer("$baseUrl/expert/earnings/payments");

    final params = <String, String>{};
    if (from != null) params['from'] = from.toUtc().toIso8601String();
    if (to != null) params['to'] = to.toUtc().toIso8601String();

    if (params.isNotEmpty) {
      buffer.write("?");
      buffer.write(Uri(queryParameters: params).query);
    }

    final res = await http.get(
      Uri.parse(buffer.toString()),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    final body = jsonDecode(res.body);

    if (res.statusCode >= 400) {
      throw Exception(body['error'] ?? 'Failed to load payments list');
    }

    return body['items'] as List<dynamic>;
  }

}
