//service/push.service.js
import admin from "../config/firebaseAdmin.js";
import User from "../models/user/user.model.js";
import Notification from "../models/notification.model.js";

export async function notifyUser(userId, { title, body, data = {}, link = "" }) {
  // 1) نخزن إشعار داخل التطبيق
  const saved = await Notification.create({ user: userId, title, body, data, link });

  // 2) نجيب كل tokens
  const user = await User.findById(userId).lean();
  const tokens = (user?.fcmTokens || []).map(t => t.token).filter(Boolean);
  if (!tokens.length) return { saved, sent: 0 };

  // 3) نرسل FCM
  const msg = {
    tokens,
    notification: { title, body },
    data: {
      ...Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])),
      link: link || "",
      notificationId: String(saved._id),
    },
  };

  const res = await admin.messaging().sendEachForMulticast(msg);


  const invalidIdx = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code || "";
    if (code.includes("registration-token-not-registered") || code.includes("invalid-registration-token")) {
      invalidIdx.push(i);
    }
  });

  if (invalidIdx.length) {
    const invalidTokens = invalidIdx.map(i => tokens[i]);
    await User.updateOne(
      { _id: userId },
      { $pull: { fcmTokens: { token: { $in: invalidTokens } } } }
    );
  }

  return { saved, sent: res.successCount, failed: res.failureCount };
}
