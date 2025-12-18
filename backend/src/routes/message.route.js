// src/routes/message.route.js
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import {
  listMyConversations,
  getOrCreateConversation,
  listMessagesForConversation,
  sendMessageInConversation,
   getUnreadMessagesCount,
} from "../controllers/message.controller.js";

const router = Router();

/**
 * 🔹 GET /api/messages/conversations
 * - كل المحادثات الخاصة باليوزر الحالي
 */
router.get("/conversations", auth(), listMyConversations);

router.get("/unread-count", auth(), getUnreadMessagesCount);
/**
 * 🔹 POST /api/messages/conversations
 * - إنشاء / إرجاع محادثة بين CUSTOMER & EXPERT
 *   - لو اليوزر CUSTOMER: body = { expertId }
 *   - لو اليوزر EXPERT:   body = { customerId }
 */
router.post("/conversations", auth(), getOrCreateConversation);

/**
 * 🔹 GET /api/messages/conversations/:conversationId/messages
 * - جلب رسائل المحادثة
 */
router.get(
  "/conversations/:conversationId/messages",
  auth(),
  listMessagesForConversation
);

/**
 * 🔹 POST /api/messages/conversations/:conversationId/messages
 * - إرسال رسالة جديدة (نص + مرفق اختياري)
 */
router.post(
  "/conversations/:conversationId/messages",
  auth(),
  sendMessageInConversation
);

export default router;
