import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class NotificationsAPI {
  static String get baseUrl => "${ApiConfig.baseUrl}/api/notifications";

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<int> getUnreadCount() async {
    final token = await _token();
    if (token == null) return 0;

    final res = await http.get(
      Uri.parse("$baseUrl/unread-count"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body);
    return (data["count"] ?? 0) as int;
  }

  static Future<List<Map<String, dynamic>>> getAll({int limit = 100}) async {
    final token = await _token();
    if (token == null) return [];

    final res = await http.get(
      Uri.parse("$baseUrl"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);

    final items = (data["items"] ?? []) as List;
    return items.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<void> markAllAsRead() async {
    final token = await _token();
    if (token == null) return;

    await http.patch(
      Uri.parse("$baseUrl/read-all"),
      headers: {"Authorization": "Bearer $token"},
    );
  }

  static Future<void> markOneAsRead(String id) async {
    final token = await _token();
    if (token == null) return;

    await http.patch(
      Uri.parse("$baseUrl/$id/read"),
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
