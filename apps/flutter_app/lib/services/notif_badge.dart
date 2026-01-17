import 'package:flutter/foundation.dart';
import 'notifications_api.dart';

class NotifBadge {
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  static Future<void> refresh() async {
    try {
      final c = await NotificationsAPI.getUnreadCount();
      unread.value = c;
    } catch (_) {}
  }

  // اختياري لو بدك “يزيد 1” فور وصول push بدون API
  static void bump() {
    unread.value = unread.value + 1;
  }
}
