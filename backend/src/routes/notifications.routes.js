import { Router } from "express";
import { auth } from "../middleware/auth.js";
import Notification from "../models/notification.model.js";

const router = Router();

/* ======================================================
   🟦 1) Get All Notifications (Latest First)
   GET /api/notifications
====================================================== */
router.get("/", auth(), async (req, res) => {
  try {
    const items = await Notification.find({ user: req.user.id })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    res.json({ items });
  } catch (e) {
    res.status(500).json({ message: "Error fetching notifications", error: e.message });
  }
});

/* ======================================================
   🟦 2) Get Unread Count (Badge)
   GET /api/notifications/unread-count
====================================================== */
router.get("/unread-count", auth(), async (req, res) => {
  try {
    const count = await Notification.countDocuments({
      user: req.user.id,
      readAt: null,
    });

    res.json({ count });
  } catch (e) {
    res.status(500).json({ message: "Error fetching unread count", error: e.message });
  }
});

/* ======================================================
   🟦 3) Mark All as Read
   PATCH /api/notifications/read-all
====================================================== */
router.patch("/read-all", auth(), async (req, res) => {
  try {
    await Notification.updateMany(
      { user: req.user.id, readAt: null },
      { $set: { readAt: new Date() } }
    );

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: "Error updating notifications", error: e.message });
  }
});

/* ======================================================
   🟦 4) Mark One as Read
   PATCH /api/notifications/:id/read
====================================================== */
router.patch("/:id/read", auth(), async (req, res) => {
  try {
    await Notification.updateOne(
      { _id: req.params.id, user: req.user.id, readAt: null },
      { $set: { readAt: new Date() } }
    );

    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ message: "Error updating notification", error: e.message });
  }
});

export default router;
