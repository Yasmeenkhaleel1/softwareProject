// src/routes/availability.routes.js
import express from "express";
import { getAvailableSlots } from "../controllers/availability.controller.js";

const router = express.Router();

/**
 * ✅ Route: GET /api/public/experts/:expertProfileId/availability/slots
 * 🎯 الهدف: جلب المواعيد المتاحة لخبير معين
 * 📌 expertProfileId = ExpertProfile._id (وليس User._id)
 * 📌 يمكن إضافة query مثل: ?date=2025-11-09
 */
router.get("/public/experts/:expertProfileId/availability/slots", getAvailableSlots);

export default router;
