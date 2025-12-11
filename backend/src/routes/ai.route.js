// src/routes/ai.route.js
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import { chatWithAssistant, getMyAiHistory } from "../controllers/ai.controller.js";

const router = Router();

// ✅ إرسال رسالة للـ AI
router.post("/chat", auth(), chatWithAssistant);

// ✅ جلب آخر محادثة AI
router.get("/history", auth(), getMyAiHistory);

export default router;
