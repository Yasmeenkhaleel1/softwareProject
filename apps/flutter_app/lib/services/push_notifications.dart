// lib/services/push_notifications.dart
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../api/api_service.dart';
import 'notif_badge.dart';
import 'notifications_api.dart';
import 'notif_badge.dart';

class PushNotifications {
  static final _messaging = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // ✅ callback للتوجيه داخل التطبيق (main.dart يمررها)
  static Future<void> Function(String link)? _onLink;

  static void configure({Future<void> Function(String link)? onLink}) {
    _onLink = onLink;
  }

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

    // 0) أول تحديث للبادج
    await NotifBadge.refresh();

    // 1) Permissions (مهم للويب و iOS)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // 2) Local notifications (موبايل فقط)
    if (!kIsWeb) {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();

      // ✅ لما المستخدم يضغط على Local Notification (Android/iOS)
      await _local.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (NotificationResponse resp) async {
          final payload = resp.payload;
          if (payload == null || payload.isEmpty) return;

          try {
            final data = jsonDecode(payload);
            final link = (data['link'] ?? '').toString();
            final nid = (data['notificationId'] ?? '').toString();

            if (nid.isNotEmpty) {
              await NotificationsAPI.markOneAsRead(nid);
            }
            await NotifBadge.refresh();

            if (link.isNotEmpty) {
              await _onLink?.call(link);
            }
          } catch (_) {}
        },
      );

      // ✅ Android: إنشاء Notification Channel مرة واحدة
      final androidPlugin = _local.resolvePlatformSpecificImplementation<
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

    // 4) refresh token
    _messaging.onTokenRefresh.listen(_registerToken);

    // 5) Foreground messages (وصول إشعار والتطبيق مفتوح)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title = message.notification?.title ?? "Lost Treasures";
      final body = message.notification?.body ?? "";

      // ✅ نخلي البادج يتحدث فوراً (لأن notifyUser خزّنه في DB)
      // ممكن تستخدم refresh (أدق) أو bump (أسرع)
      await NotifBadge.refresh();

      if (!kIsWeb) {
        await _local.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.max,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          // ✅ نخزن message.data عشان نقرأ link + notificationId عند الضغط
          payload: jsonEncode(message.data),
        );
      } else {
        debugPrint("🌐 Web foreground: $title | $body");
      }
    });

    // 6) لما المستخدم يضغط على Push (التطبيق بالخلفية)
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      final link = message.data['link']?.toString() ?? "";
      final nid = message.data['notificationId']?.toString();

      if (nid != null && nid.isNotEmpty) {
        await NotificationsAPI.markOneAsRead(nid);
      }
      await NotifBadge.refresh();

      if (link.isNotEmpty) {
        await _onLink?.call(link);
      }
    });

    // 7) لما يفتح التطبيق من إشعار وهو كان مقفل
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      final link = initial.data['link']?.toString() ?? "";
      final nid = initial.data['notificationId']?.toString();

      if (nid != null && nid.isNotEmpty) {
        await NotificationsAPI.markOneAsRead(nid);
      }
      await NotifBadge.refresh();

      if (link.isNotEmpty) {
        await _onLink?.call(link);
      }
    }
  }

  static Future<void> _registerToken(String token) async {
    final platform = kIsWeb ? "web" : "android";
    await ApiService.registerPushToken(token: token, platform: platform);

    // ✅ بعد التسجيل حدّثي البادج (اختياري)
    await NotifBadge.refresh();
  }
}
