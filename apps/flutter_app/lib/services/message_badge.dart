import 'package:flutter/foundation.dart';

// لاحقًا تربطيه بـ API unread chats
class MessageBadge {
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  static Future<void> refresh() async {
    try {
      // TODO: نجيب العدد من API
      // مثال: final c = await ChatAPI.getUnreadCount();
      // unread.value = c;
    } catch (_) {}
  }

  static void bump() => unread.value = unread.value + 1;
}
