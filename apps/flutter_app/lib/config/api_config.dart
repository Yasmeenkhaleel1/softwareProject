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
 /// دالة لتصليح روابط الصور الجاية من الباك إند
  static String fixAssetUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    String u = url.trim();

    // 1) لو الرابط كامل وفيه localhost → نبدّله بـ baseUrl
    if (u.startsWith('http://localhost:5000')) {
      u = u.replaceFirst('http://localhost:5000', baseUrl);
    } else if (u.startsWith('http://10.0.2.2:5000')) {
      u = u.replaceFirst('http://10.0.2.2:5000', baseUrl);
    }
    // 2) لو مخزن path فقط مثل /uploads/experts/a.png
    else if (u.startsWith('/')) {
      u = '$baseUrl$u';
    }

    return u;
  }
}

