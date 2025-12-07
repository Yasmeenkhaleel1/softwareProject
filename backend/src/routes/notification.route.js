// routes/notification.route.js
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import Notification from "../models/notification.model.js";

const router = Router();

/* ======================================================
   🟦 1) Get All Notifications (Latest First)
====================================================== */
router.get("/", auth(), async (req, res) => {
  try {
    const notifications = await Notification.find({ userId: req.user.id })
      .sort({ createdAt: -1 })
      .limit(20);

    res.json({ notifications });
  } catch (e) {
    res.status(500).json({
      message: "Error fetching notifications",
      error: e.message,
    });
  }
});

/* ======================================================
   🟦 2) Get Unread Count (For Badge 🔴)
====================================================== */
router.get("/unread-count", auth(), async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      userId: req.user.id,
      isRead: false, 
    });

    res.json({ unread: count });
  } catch (e) {
    res.status(500).json({
      message: "Error fetching unread count",
      error: e.message,
    });
  }
});

/* ======================================================
   🟦 3) Mark All as Read
====================================================== */
router.patch("/read-all", auth(), async (req, res) => {
  try {
    await Notification.updateMany(
      { userId: req.user.id },
      { isRead: true }
    );

    res.json({ message: "All notifications marked as read" });
  } catch (e) {
    res.status(500).json({
      message: "Error updating notifications",
      error: e.message,
    });
  }
});

export default router;
