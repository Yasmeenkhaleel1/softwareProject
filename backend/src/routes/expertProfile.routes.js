// src/routes/expertProfile.routes.js
import express from "express";

import {
  createExpertProfile,
  getMyExpertProfile,
  updateMyExpertProfile,
  listExpertProfiles,
  approveExpertProfile,
  rejectExpertProfile,
  createDraftFromApproved,
  updateMyDraft,
  submitDraftForReview,
} from "../controllers/expertProfile.controller.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import { auth } from "../middleware/auth.js";

const router = express.Router();

/**
 * 🎯 قواعد الوصول:
 * - EXPERT: إنشاء/تحديث/عرض بروفايله.
 * - ADMIN: عرض جميع البروفايلات + الموافقة/الرفض.
 * - Public: عرض أي بروفايل خبير منشور.
 */

// ===== 🧠 Expert endpoints =====
router.post("/", auth("EXPERT"), createExpertProfile); // إنشاء بروفايل جديد
router.get("/me", auth("EXPERT"), getMyExpertProfile); // عرض بروفايله الشخصي
router.put("/:profileId", auth("EXPERT"), updateMyExpertProfile); // تحديث البروفايل (طالما "pending")

// ===== ✏️ Draft profile endpoints (EXPERT only) =====
router.post("/draft", auth("EXPERT"), createDraftFromApproved); // إنشاء نسخة Draft
router.put("/draft/:draftId", auth("EXPERT"), updateMyDraft); // حفظ التعديلات على الـ Draft
router.post("/draft/:draftId/submit", auth("EXPERT"), submitDraftForReview); // إرسال للمراجعة

// ===== 🛡️ Admin endpoints =====
router.get("/", auth("ADMIN"), listExpertProfiles); // archived hidden now
 // عرض جميع البروفايلات
router.put("/:id/approve", auth("ADMIN"), approveExpertProfile); // الموافقة
router.put("/:id/reject", auth("ADMIN"), rejectExpertProfile); // الرفض

// ===== 🌍 Public endpoint (عرض بروفايل خبير لأي مستخدم) =====
router.get("/view/:userId", async (req, res) => {
  try {
    const { userId } = req.params;
    const profile = await ExpertProfile.findOne({ userId }).select(
       "name bio specialization experience location gallery certificates profileImageUrl status ratingAvg ratingCount"
    );

    if (!profile)
      return res.status(404).json({ message: "Profile not found" });

    res.status(200).json(profile);
  } catch (err) {
    console.error("❌ Error fetching public profile:", err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
