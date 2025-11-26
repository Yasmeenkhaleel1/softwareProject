// lib/models/booking.dart

class Booking {
  final String id;
  final String code;
  final String status;

  // 🕒 التواريخ
  final DateTime startAtUtc;
  final DateTime endAtUtc;
  final String timezone;

  // 🧍‍♂️ الكستمر (اختياري)
  final Map<String, dynamic>? customer;

  // 🎨 معلومات الخدمة
  final Map<String, dynamic>? service;

  // 💳 الدفع
  final Map<String, dynamic>? payment;

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
      id: j['_id']?.toString() ?? '',
      code: j['code'] ?? '',
      status: j['status'] ?? 'PENDING',

      // correct parsing to UTC
      startAtUtc: DateTime.parse(j['startAt']).toUtc(),
      endAtUtc: DateTime.parse(j['endAt']).toUtc(),

      timezone: j['timezone'] ?? 'Asia/Hebron',

      customer: j['customer'] as Map<String, dynamic>?,
      service: j['service'] as Map<String, dynamic>?,
      payment: j['payment'] as Map<String, dynamic>?,
    );
  }
}
