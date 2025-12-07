import { Router } from "express";
import admin from "../config/firebaseAdmin.js";

const router = Router();

// 🔥 إرسال إشعار
router.post("/send", async (req, res) => {
  try {
    const { token, title, body } = req.body;

    const message = {
      token,
      notification: { title, body }
    };

    await admin.messaging().send(message);

    res.json({ success: true, message: "🔔 Notification Sent Successfully" });

  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.message });
  }
});

export default router;
