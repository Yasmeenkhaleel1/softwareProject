import 'package:flutter/foundation.dart';
import '../../api/api_service.dart';

class MessageBadge {
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  static Future<void> refresh() async {
    try {
      final c = await ApiService.fetchUnreadMessagesCount();
      unread.value = c;
    } catch (_) {}
  }

  static void bump() => unread.value = unread.value + 1;
}
