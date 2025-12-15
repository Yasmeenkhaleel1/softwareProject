import { Router } from "express";
import { auth } from "../middleware/auth.js";
import User from "../models/user/user.model.js";
import { notifyUser } from "../services/push.service.js";

const router = Router();

/* ======================================================
   🟩 Register FCM Token
   POST /api/push/register
====================================================== */
router.post("/register", auth(), async (req, res) => {
  try {
    const { token, platform, deviceId = "", userAgent = "" } = req.body;

    if (!token || !platform) {
      return res.status(400).json({ message: "token & platform are required" });
    }

    // remove token if already exists then add it fresh
    await User.updateOne({ _id: req.user.id }, { $pull: { fcmTokens: { token } } });

    await User.updateOne(
      { _id: req.user.id },
      {
        $push: {
          fcmTokens: { token, platform, deviceId, userAgent, lastSeenAt: new Date() },
        },
      }
    );

    // (اختياري) إشعار ترحيبي للتجربة
    await notifyUser(req.user.id, {
      title: "✅ Login Successful",
      body: "Welcome back to Lost Treasures!",
      data: { type: "LOGIN" },
      link: "/",
    });

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: "Error registering token", error: e.message });
  }
});

export default router;
