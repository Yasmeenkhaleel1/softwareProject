// lib/config/api_config.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiConfig {
  // 🔑 مفتاح Stripe العلني (publishable key)
  static const String stripePublishableKey = "pk_test_51SYp9sFqZeISylG0JkimZuunU3Wq71PW2bokzILfnN7QMk4ZLRgDTfSc3iTds00QYSbris2s4CySmzkoeDH0JV1X00q8triO40";

  // 🌐 عنوان الـ API حسب المنصّة
  static String get baseUrl {
    if (kIsWeb) return "http://localhost:5000";
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "http://10.0.2.2:5000";
    }
    return "http://localhost:5000";
  }
}

