import admin from "../config/firebaseAdmin.js";

export async function sendFCM(toToken, title, body, data = {}) {
  if (!toToken) {
    console.warn("❌ No FCM token — cannot send push notification");
    return;
  }

  const message = {
    token: toToken,
    notification: { title, body },
    data,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("📩 FCM sent:", response);
  } catch (err) {
    console.error("❌ FCM error:", err);
  }
}
