import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../api/api_service.dart';

class PushNotifications {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String webVapidKey =
      "BEwxxtGqyLTm2hn2mPhwx6mdqDqkL0OKBL8Zr2t0U5pO6AuvLcw0aWtbuERYfgm1ZTTq3DLB7VIH3UCIxiK0rko";

  // ✅ Channel ثابت (لا تغيّري الـ id)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'lost_treasures',
    'Lost Treasures',
    description: 'Lost Treasures notifications',
    importance: Importance.max,
  );

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1) Permissions (مهم للويب و iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2) Local notifications (موبايل فقط)
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();

      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      // ✅ Android: إنشاء Notification Channel مرة واحدة
      final androidPlugin =
          _local.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(_channel);

        // ✅ Android 13+: طلب إذن الإشعارات (مهم)
        await androidPlugin.requestNotificationsPermission();
      }

      // iOS: عرض الإشعار في الـ foreground
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 3) Token
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? webVapidKey : null,
    );
    debugPrint("FCM TOKEN: $token");

    if (token != null) {
      await _registerToken(token);
    }

    // 4) refresh
    _messaging.onTokenRefresh.listen(_registerToken);

    // 5) Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? "Lost Treasures";
      final body = message.notification?.body ?? "";

      if (!kIsWeb) {
        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id, // ✅ نفس الـ id تبع الـ channel
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          payload: jsonEncode(message.data),
        );
      } else {
        debugPrint("🌐 Web foreground: $title | $body");
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final link = message.data['link'];
      // TODO navigation
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      final link = initial.data['link'];
      // TODO navigation
    }
  }

  static Future<void> _registerToken(String token) async {
    final platform = kIsWeb ? "web" : "android";
    await ApiService.registerPushToken(token: token, platform: platform);
  }
}