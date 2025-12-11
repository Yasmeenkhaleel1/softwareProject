// lib/api/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart'; 
import '../config/api_config.dart';

class ApiService {
  // 🔥 لأن المشروع يعمل فقط على الويب → نستخدم localhost دائماً
  static String get baseUrl => "${ApiConfig.baseUrl}/api";


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

  // ---------- DISPUTES ----------


  static Future<List<dynamic>> getDisputableBookings() async {
    final token = await getToken();
    // ✅ هذا الـ endpoint اللي اتفقنا عليه في الباك إند
    final url = "$baseUrl/public/disputes/bookings";

    final res = await http.get(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
    );

    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(body["message"] ?? "Failed to load disputable bookings");
    }
    return body["bookings"] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createDispute({
    required String bookingId,
    required String message,
    String type = "OTHER",
    List<String> attachments = const [], // 🟣 جديد: قائمة الروابط
  }) async {
    final token = await getToken();
    final url = "$baseUrl/public/disputes";

    final res = await http.post(
      Uri.parse(url),
      headers: {
        "Content-Type": "application/json",
        if (token != null) "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "bookingId": bookingId,
        "message": message,
        "type": type,
        "attachments": attachments, // 🟣 نرسلها للباك إند
      }),
    );

    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw Exception(
        body["message"] ?? body["error"] ?? "Failed to open dispute",
      );
    }
    return body;
  }

 // 🔹 جلب حجوزات الكستمر للتقويم
 static Future<List<dynamic>> fetchCustomerBookings({
    required String customerId,
    DateTime? from,
    DateTime? to,
    String? status,
  }) async {
    final token = await getToken();

    String? fromStr;
    String? toStr;
    if (from != null) {
      fromStr = from.toUtc().toIso8601String();
    }
    if (to != null) {
      toStr = to.toUtc().toIso8601String();
    }

    final params = <String, String>{
      'customerId': customerId,
      'page': '1',
      'limit': '200',
      if (status != null) 'status': status,
      if (fromStr != null) 'from': fromStr,
      if (toStr != null) 'to': toStr,
    };

    final uri = Uri.parse('$baseUrl/public/bookings')
        .replace(queryParameters: params);

    final res = await http.get(uri, headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });

    if (res.statusCode >= 400) {
      throw Exception('Failed to load bookings: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['bookings'] as List?) ?? [];
  }

  /// 🔹 جلب حجوزات الخبير (تُستخدم في صفحة My Customers)
  static Future<List<dynamic>> fetchExpertBookings({
    DateTime? from,
    DateTime? to,
    String? status,
    int page = 1,
    int limit = 200,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not logged in');
    }

    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (status != null) 'status': status,
      if (from != null) 'from': from.toUtc().toIso8601String(),
      if (to != null) 'to': to.toUtc().toIso8601String(),
    };

    final uri = Uri.parse('$baseUrl/expert/bookings')
        .replace(queryParameters: params);

    final res = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode >= 400) {
      throw Exception('Failed to load expert bookings: ${res.body}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    // listBookings بيرجع { data, total, page, pages }
    return (body['data'] as List?) ?? [];
  }

  // 🔹 إرسال تقييم للحجز (ويحدّث تقييم الخدمة)
  static Future<void> submitBookingReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    final token = await getToken();
    if (token == null) {
      throw Exception("Not authenticated");
    }

    final uri =
        Uri.parse('$baseUrl/customer/bookings/$bookingId/review');

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'rating': rating,
        'comment': comment ?? '',
      }),
    );

    if (res.statusCode >= 400) {
      throw Exception('Failed to submit review: ${res.body}');
    }
  }

    // =======================
  //  MESSAGING / CHAT API
  // =======================

  /// جلب كل المحادثات الخاصة باليوزر الحالي (Customer أو Expert)
  static Future<List<Map<String, dynamic>>> fetchMyConversations() async {
    final token = await getToken();
    if (token == null) throw Exception('Not logged in');

    final res = await http.get(
      Uri.parse('$baseUrl/messages/conversations'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load conversations (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map;
    final list = (decoded['conversations'] as List? ?? []);

    return list
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e as Map),
        )
        .toList();
  }

  /// CUSTOMER يبدأ محادثة مع خبير
  static Future<Map<String, dynamic>> getOrCreateConversationAsCustomer({
    required String expertId,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not logged in');

    final res = await http.post(
      Uri.parse('$baseUrl/messages/conversations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'expertId': expertId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to create/get conversation (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map;
    return Map<String, dynamic>.from(decoded['conversation'] as Map);
  }

  /// EXPERT يبدأ محادثة مع كستمر
  static Future<Map<String, dynamic>> getOrCreateConversationAsExpert({
    required String customerId,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not logged in');

    final res = await http.post(
      Uri.parse('$baseUrl/messages/conversations'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'customerId': customerId,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to create/get conversation (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map;
    return Map<String, dynamic>.from(decoded['conversation'] as Map);
  }

  /// جلب رسائل محادثة معيّنة
  static Future<List<Map<String, dynamic>>> fetchConversationMessages(
    String conversationId, {
    int limit = 50,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not logged in');

    final res = await http.get(
      Uri.parse(
        '$baseUrl/messages/conversations/$conversationId/messages?limit=$limit',
      ),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load messages (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map;
    final list = (decoded['messages'] as List? ?? []);

    return list
        .map<Map<String, dynamic>>(
          (e) => Map<String, dynamic>.from(e as Map),
        )
        .toList();
  }

  /// إرسال رسالة (نص + مرفق اختياري)
  static Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    String? text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    String? bookingId,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not logged in');

    if ((text == null || text.trim().isEmpty) &&
        (attachmentUrl == null || attachmentUrl.isEmpty)) {
      throw Exception('Message must have text or attachment');
    }

    final body = <String, dynamic>{};
    if (text != null) body['text'] = text.trim();
    if (attachmentUrl != null) body['attachmentUrl'] = attachmentUrl;
    if (attachmentName != null) body['attachmentName'] = attachmentName;
    if (attachmentType != null) body['attachmentType'] = attachmentType;
    if (bookingId != null) body['bookingId'] = bookingId;

    final res = await http.post(
      Uri.parse(
          '$baseUrl/messages/conversations/$conversationId/messages'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (res.statusCode != 201) {
      throw Exception('Failed to send message (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map;
    return Map<String, dynamic>.from(decoded['message'] as Map);
  }

  /// رفع مرفق شات (نعيد استخدام /upload/disputes)
  static Future<Map<String, dynamic>> uploadChatAttachment(
      PlatformFile file) async {
    final token = await getToken();
    if (token == null) throw Exception('Not logged in');

    if (file.bytes == null) {
      throw Exception('File bytes are null (web/file_picker issue)');
    }

    final uri = Uri.parse('$baseUrl/upload/disputes');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'files',
        file.bytes!,
        filename: file.name,
      ),
    );

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to upload attachment (${res.statusCode})');
    }

    final decoded = jsonDecode(res.body) as Map;
    final files = (decoded['files'] as List? ?? []);
    if (files.isEmpty) throw Exception('No file returned from server');

    final first = Map<String, dynamic>.from(files.first as Map);
    // structure: {originalName, url, size, mimeType}
    return first;
  }


// =======================
//  AI Assistant
// =======================
static Future<String> askAssistant({
  required String question,
  Map<String, dynamic>? extraContext,
}) async {
  final token = await getToken();

  // 👈 مهم: لو عندك الراوت /api/ai/chat استخدميه
  final uri = Uri.parse("$baseUrl/assistant/chat");

  final res = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'message': question,
      if (extraContext != null) 'context': extraContext,
    }),
  );

  final body = jsonDecode(res.body) as Map<String, dynamic>;

  if (res.statusCode >= 400) {
    throw Exception(body['error'] ?? body['message'] ?? 'Assistant error');
  }

  // 👈 هنا التعديل المهم:
  // نحاول نقرأ reply أولاً، ولو مش موجود نرجع answer أو message
  final dynamic raw =
      body['reply'] ?? body['answer'] ?? body['message'] ?? 'Sorry, I could not answer that.';

  return raw.toString();
}

}
