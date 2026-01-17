// src/controllers/ai.controller.js
import AiSession from "../models/aiSession.model.js";
import { generateAssistantReply } from "../services/aiAssistant.service.js";

/**
 * 🎯 POST /api/ai/chat
 * body: { message: string, sessionId?: string }
 *
 * - يسمح فقط للكستمر باستخدامه (role = CUSTOMER)
 * - يحضّر history من AiSession
 * - ينادي generateAssistantReply
 * - يحفظ السؤال + جواب AI في AiSession
 */
export const chatWithAssistant = async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    if (role !== "CUSTOMER") {
      return res.status(403).json({
        message: "AI assistant is currently available for customers only.",
      });
    }

    const { message, sessionId } = req.body || {};
    if (!message || !message.toString().trim()) {
      return res
        .status(400)
        .json({ message: "Message is required and cannot be empty." });
    }

    // 1) جلب أو إنشاء جلسة AiSession
    let session;

    if (sessionId) {
      session = await AiSession.findOne({ _id: sessionId, user: userId });
    }

    if (!session) {
      // لو ما في sessionId أو مش موجودة → خد آخر جلسة للمستخدم
      session = await AiSession.findOne({ user: userId }).sort({
        lastInteractionAt: -1,
      });
    }

    if (!session) {
      session = await AiSession.create({
        user: userId,
        messages: [],
      });
    }

    // 2) history: آخر 10 رسائل فقط
    const history = (session.messages || []).slice(-10);

    // 3) استخدم الخدمة لتوليد الرد
    const aiResult = await generateAssistantReply({
      userId,
      userQuestion: message.toString(),
      historyMessages: history,
    });

    // 4) حفظ الرسالة + رد المساعد في الجلسة
    session.messages.push(
      {
        role: "user",
        content: message.toString(),
      },
      {
        role: "assistant",
        content: aiResult.reply,
      }
    );
    session.lastInteractionAt = new Date();
    await session.save();

    return res.status(200).json({
      sessionId: session._id,
      reply: aiResult.reply,
      source: aiResult.source, // RULE or AI
      context: aiResult.context, // اختياري لو حابة تعرضي شيء في الـ UI
    });
  } catch (e) {
    console.error("❌ chatWithAssistant error:", e);
    return res
      .status(500)
      .json({ message: "Server error", error: e.message });
  }
};

/**
 * 📜 GET /api/ai/history
 * - يرجّع آخر جلسة AI للمستخدم (لو حابة تعرضي المحادثة السابقة في الواجهة)
 */
export const getMyAiHistory = async (req, res) => {
  try {
    const userId = req.user.id;

    const session = await AiSession.findOne({ user: userId })
      .sort({ lastInteractionAt: -1 })
      .lean();

    if (!session) {
      return res.json({ session: null, messages: [] });
    }

    return res.json({
      sessionId: session._id,
      messages: session.messages || [],
    });
  } catch (e) {
    console.error("❌ getMyAiHistory error:", e);
    return res
      .status(500)
      .json({ message: "Server error", error: e.message });
  }
};