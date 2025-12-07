import admin from "../config/firebaseAdmin.js";
import Notification from "../models/notification.model.js";
import User from "../models/user/user.model.js";  


// 🔥 وظيفة عامة يمكن إعادة استعمالها
export async function sendNotificationToUser(userId, title, message) {
  const user = await User.findById(userId).lean();
  if (!user?.fcmToken) {
    console.log("⚠ لا يوجد FCM Token لهذا المستخدم:", userId);
    return;
  }

  // 🔥 إرسال FCM
  await admin.messaging().send({
    token: user.fcmToken,
    notification: { title, body: message }
  });

  // 📥 تخزين الإشعار بالداتابيس لعرضه داخل الـ App
  await Notification.create({
    userId,
    title,
    message,
    type: "info"
  });

  console.log("📩 Notification Sent →", userId, title);
}
