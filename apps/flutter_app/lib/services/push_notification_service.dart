// lib/services/push_notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'dart:developer';

class PushNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // 🔗 Endpoint في الباك إند لتخزين الـ FCM Token
  static const String serverUrl = "http://localhost:5000/api/fcm/register-fcm";

  /// 🚀 يطلب الإذن + يجلب التوكن ويرسله للسيرفر
  static Future<void> initFCM() async {
    // 1) طلب الإذن
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log("🔔 FCM Permission: ${settings.authorizationStatus}");

    // 2) جلب الـ Token (مع VAPID للويب)
    String? token;
    if (kIsWeb) {
      token = await _fcm.getToken(
        vapidKey: "BEwxxtGqyLTm2hn2mPhwx6mdqDqkL0OKBL8Zr2t0U5pO6AuvLcw0aWtbuERYfgm1ZTTq3DLB7VIH3UCIxiK0rko", // ⬅️ ضعي هنا Web Push certificate من Firebase
      );
    } else {
      token = await _fcm.getToken();
    }

    if (token == null) {
      log("⚠️ FCM Token is null");
      return;
    }

    log("🔥 FCM TOKEN => $token");

    // 3) حفظه محليًا
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);

    // 4) إرساله للسيرفر مع JWT Auth
    final authToken = prefs.getString('token');
    if (authToken == null) {
      log("⚠️ No auth token found → won't send FCM token to server");
      return;
    }

    try {
      final res = await http.post(
        Uri.parse(serverUrl),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"token": token}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        log("📩 FCM token sent to server successfully");
      } else {
        log("⚠️ Failed to send FCM token: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      log("❌ Error sending FCM token to server: $e");
    }

    // (اختياري) فقط لوجات
    FirebaseMessaging.onMessage.listen((msg) {
      log("💬 [PushNotificationService] onMessage: "
          "${msg.notification?.title} | ${msg.notification?.body}");
    });

    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      log("📬 [PushNotificationService] onMessageOpenedApp");
    });
  }
}
