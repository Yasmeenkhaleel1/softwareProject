// src/routes/expertProfile.routes.js
import express from "express";
import {
  createExpertProfile,
  getMyExpertProfile,
  updateMyExpertProfile,
  listExpertProfiles,
  approveExpertProfile,
  rejectExpertProfile,
} from "../controllers/expertProfile.controller.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import { auth } from "../middleware/auth.js"; // ✅ استدعاء الميدلوير

const router = express.Router();

/**
 * Auth Rules:
 * - EXPERT فقط يستطيع إنشاء أو تعديل بروفايله.
 * - ADMIN فقط يستطيع الموافقة أو الرفض.
 * - أي مستخدم مسجل يمكنه عرض بروفايله.
 * - العرض العام مفتوح للجميع (view/:userId).
 */

// ===== User (Expert) endpoints =====
router.post("/expertProfiles", auth("EXPERT"), createExpertProfile);
router.get("/expertProfiles/me", auth(), getMyExpertProfile);
router.patch("/expertProfiles/:profileId", auth("EXPERT"), updateMyExpertProfile);

// ===== Admin endpoints =====
router.get("/expertProfiles", auth("ADMIN"), listExpertProfiles); // ?status=pending
router.patch("/expertProfiles/:id/approve", auth("ADMIN"), approveExpertProfile);
router.patch("/expertProfiles/:id/reject", auth("ADMIN"), rejectExpertProfile);

// ===== Public endpoint (عرض بروفايل خبير لأي مستخدم) =====
router.get("/expertProfiles/view/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const profile = await ExpertProfile.findOne({ userId });

    if (!profile)
      return res.status(404).json({ message: "Profile not found" });

    res.status(200).json(profile);
  } catch (err) {
    console.error("❌ Error fetching profile:", err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
