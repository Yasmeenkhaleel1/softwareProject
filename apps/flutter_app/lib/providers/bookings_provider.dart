// lib/providers/bookings_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/booking.dart';
class BookingsProvider with ChangeNotifier {
static const baseUrl = 'http://localhost:5000/api';
List<Booking> items = [];
int total = 0;
int page = 1;
int pages = 1;
bool loading = false;
String? error;
Future<String?> _token() async {
final p = await SharedPreferences.getInstance();
return p.getString('token');
}
Future<void> fetch({
String? status,
DateTime? from,
DateTime? to,
int page = 1,
int limit = 10,
}) async {
try {
loading = true; error = null; notifyListeners();
final t = await _token();
final params = <String, String>{
'page': '$page', 'limit': '$limit'
};
if (status != null && status.isNotEmpty) params['status'] = status;
if (from != null) params['from'] = from.toUtc().toIso8601String();
if (to != null) params['to'] = to.toUtc().toIso8601String();
final uri = Uri.parse('$baseUrl/expert/bookings').replace(queryParameters: params);
final res = await http.get(uri, headers: { 'Authorization': 'Bearer $t' });
if (res.statusCode != 200) throw Exception('Failed to load (${res.statusCode})');
final j = jsonDecode(res.body);
items = (j['data'] as List).map((e) => Booking.fromJson(e)).toList();
total = j['total']; this.page = j['page']; pages = j['pages'];
} catch (e) {
error = e.toString();
} finally {
loading = false; notifyListeners();
}
}
Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body)
async {
final t = await _token();
final res = await http.post(
Uri.parse('$baseUrl$path'),
headers: {
'Authorization': 'Bearer $t',
'Content-Type': 'application/json',
},
body: jsonEncode(body),
);
final j = jsonDecode(res.body);
if (res.statusCode >= 400) throw Exception(j['error'] ?? 'Request failed');
return j;
}
Future<void> accept(String id) async { await _post('/expert/bookings/$id/accept', {}); }
Future<void> decline(String id) async { await _post('/expert/bookings/$id/decline', {}); }
Future<void> start(String id) async { await _post('/expert/bookings/$id/start', {}); }
Future<void> complete(String id) async { await _post('/expert/bookings/$id/complete', {}); }
Future<void> cancel(String id, {String? reason}) async { await _post('/expert/bookings/$id/cancel', { 'reason': reason }); }
Future<void> reschedule(String id, DateTime newStart) async {
await _post('/expert/bookings/$id/reschedule', { 'startAtIso':newStart.toUtc().toIso8601String() });
}
Future<Map<String, num>> overview({DateTime? from, DateTime? to}) async {
final t = await _token();
final params = <String, String>{};
if (from != null) params['from'] = from.toUtc().toIso8601String();
if (to != null) params['to'] = to.toUtc().toIso8601String();
final uri = Uri.parse('$baseUrl/expert/bookings/overview')
    .replace(queryParameters: params);
final res = await http.get(
    uri, 
    headers:
 { 'Authorization': 'Bearer $t' });
if (res.statusCode != 200) throw Exception('Overview failed');
final j = jsonDecode(res.body);
//{count_status {تبسيط: إعادة هيكل بسيط 
final Map<String, num> map = {};
for (final row in (j['data'] as List)) {
map[row['_id'] as String] = (row['count'] as num);
}
return map;
}
}