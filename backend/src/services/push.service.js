// src/services/push.service.js
import admin from "../config/firebaseAdmin.js";
import User from "../models/user/user.model.js";
import Notification from "../models/notification.model.js";

export async function notifyUser(userId, { title, body, data = {}, link = "" }) {
  // 1) نخزن إشعار داخل التطبيق (الجرس)
  const saved = await Notification.create({
    user: userId,
    title,
    body,
    data,
    link,
  });

  // 2) نجيب كل tokens
  const user = await User.findById(userId).lean();
  const tokens = (user?.fcmTokens || []).map((t) => t.token).filter(Boolean);
  if (!tokens.length) return { saved, sent: 0, failed: 0 };

  // 3) نخلي data كلها Strings (FCM requirement)
  const dataString = Object.fromEntries(
    Object.entries(data || {}).map(([k, v]) => [k, String(v)])
  );

  const msg = {
    tokens,

    // ✅ هذا اللي يخلي Push يطلع “من برا” (notification tray) على الموبايل
    notification: { title, body },

    // ✅ هذا اللي نستخدمه للتوجيه داخل التطبيق + navigation
    data: {
      ...dataString,
      link: link || "",
      notificationId: String(saved._id),
    },

    // ✅ Android: priority عالي + sound
    android: {
      priority: "high",
      notification: {
        sound: "default",
      },
    },

    // ✅ iOS: sound + priority عالي
    apns: {
      headers: {
        "apns-priority": "10",
      },
      payload: {
        aps: {
          sound: "default",
          // contentAvailable: true (اختياري لو بدك background processing)
        },
      },
    },

    // ✅ Web: فتح الرابط عند الضغط على الإشعار (في الويب)
    webpush: {
      headers: {
        Urgency: "high",
      },
      fcmOptions: {
        link: link || "/", // مهم جدًا للويب
      },
    },
  };

  const res = await admin.messaging().sendEachForMulticast(msg);

  // تنظيف Tokens غير صالحة
  const invalidIdx = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code || "";
    if (
      code.includes("registration-token-not-registered") ||
      code.includes("invalid-registration-token")
    ) {
      invalidIdx.push(i);
    }
  });

  if (invalidIdx.length) {
    const invalidTokens = invalidIdx.map((i) => tokens[i]);
    await User.updateOne(
      { _id: userId },
      { $pull: { fcmTokens: { token: { $in: invalidTokens } } } }
    );
  }

  return { saved, sent: res.successCount, failed: res.failureCount };
}
