//fcm.route
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import User from "../models/user/user.model.js";   


const router = Router();

// 🔥 يستقبل التوكن من تطبيق Flutter ويخزنه
router.post("/register-fcm", auth(), async (req, res) => {
  try {
    const { token } = req.body;
    if (!token) return res.status(400).json({ message: "FCM token required" });

    await User.findByIdAndUpdate(req.user.id, { fcmToken: token });

    res.json({ success: true, message: "FCM Token registered ✔" });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

export default router;
