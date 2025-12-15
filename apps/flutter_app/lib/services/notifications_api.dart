import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
class NotificationsAPI {
 static String get baseUrl => "${ApiConfig.baseUrl}/api/notifications";

  // 🔹 Get token
  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // 🔴 unread count
  static Future<int> getUnreadCount() async {
    final token = await _token();
    if (token == null) return 0;

    final res = await http.get(
      Uri.parse("$baseUrl/unread-count"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 200) return 0;

    final data = jsonDecode(res.body);
    return data["unread"] ?? 0;
  }

  // 🔵 mark all as read
  static Future<void> markAllAsRead() async {
    final token = await _token();
    if (token == null) return;

    await http.patch(
      Uri.parse("$baseUrl/read-all"),
      headers: {"Authorization": "Bearer $token"},
    );
  }
}
