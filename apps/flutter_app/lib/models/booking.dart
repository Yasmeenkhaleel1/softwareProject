// lib/models/booking.dart
class Booking {
final String id;
final String code;
final String status;
final DateTime startAtUtc;
final DateTime endAtUtc;
final String timezone;
final Map<String, dynamic>? customer; // {name,email}
final Map<String, dynamic>? service; // {title,durationMinutes}
final Map<String, dynamic>? payment; // {status,amount,currency}
Booking({
required this.id,
required this.code,
required this.status,
required this.startAtUtc,
required this.endAtUtc,
required this.timezone,
this.customer,
this.service,
this.payment,
});
factory Booking.fromJson(Map<String, dynamic> j) {
return Booking(
id: j['_id'],
code: j['code'] ?? '',
status: j['status'] ?? 'PENDING',
startAtUtc: DateTime.parse(j['startAt']).toUtc(),
endAtUtc: DateTime.parse(j['endAt']).toUtc(),
timezone: j['timezone'] ?? 'Asia/Hebron',
customer: j['customer'],
service: j['service'],
payment: j['payment'],
);
}
}