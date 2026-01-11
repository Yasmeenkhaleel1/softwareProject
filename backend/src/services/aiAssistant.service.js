import OpenAI from "openai";
import Booking from "../models/booking.model.js";
import Service from "../models/expert/service.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

const localAI = new OpenAI({
  baseURL: "http://127.0.0.1:11434/v1",
  apiKey: "ollama",
});

/**
 * 🛠 1. دالة تجميع بيانات المستخدم (يجب أن تكون موجودة ومعرفة)
 */
async function buildCustomerContext(userId) {
  try {
    const [latestBooking, activeCount, totalCount] = await Promise.all([
      Booking.findOne({ customer: userId })
        .sort({ startAt: -1 })
        .populate({ path: "service", select: "title", model: Service })
        .populate({ path: "expert", select: "name", model: ExpertProfile })
        .lean(),
      Booking.countDocuments({
        customer: userId,
        status: { $in: ["PENDING", "CONFIRMED", "IN_PROGRESS"] },
      }),
      Booking.countDocuments({ customer: userId }),
    ]);

    let latestSummary = "لا يوجد حجوزات سابقة.";
    if (latestBooking) {
      latestSummary = 
        `- الخدمة: ${latestBooking.service?.title || "غير معروف"}\n` +
        `- الخبير: ${latestBooking.expert?.name || "غير معروف"}\n` +
        `- الحالة: ${latestBooking.status}\n` +
        `- التاريخ: ${latestBooking.startAt?.toLocaleDateString('ar-EG') || ""}`;
    }

    return {
      activeBookingsCount: activeCount,
      totalBookingsCount: totalCount,
      latestBookingSummary: latestSummary,
    };
  } catch (error) {
    console.error("Error building context:", error);
    return { activeBookingsCount: 0, totalBookingsCount: 0, latestBookingSummary: "خطأ في جلب البيانات" };
  }
}

/**
 * 🧠 2. دالة استدعاء الذكاء الاصطناعي
 */
async function callLLM({ systemPrompt, userMessage, history }) {
  try {
    const response = await localAI.chat.completions.create({
      model: "llama3.2",
      messages: [
        { role: "system", content: systemPrompt },
        ...history,
        { role: "user", content: userMessage },
      ],
      temperature: 0.7,
    });
    return response.choices[0].message.content.trim();
  } catch (error) {
    console.error("AI Call Error:", error);
    return "عذراً، المحرك الذكي لا يستجيب حالياً.";
  }
}

/**
 * 🎯 3. الدالة الرئيسية المصدرة (التي يتم استدعاؤها من الـ Controller)
 */
export async function generateAssistantReply({ userId, userQuestion, historyMessages }) {
  // ✅ الآن الدالة معرفة في الأعلى ولن يظهر الخطأ
  const ctx = await buildCustomerContext(userId);

  // نظام القواعد السريعة
  if (userQuestion.includes("حجز") || userQuestion.includes("booking")) {
     // يمكنك وضع منطق القواعد هنا أو تركه للذكاء الاصطناعي
  }

  const systemPrompt = `أنت مساعد ذكي لمنصة Lost Treasures. 
    بيانات المستخدم: لديه ${ctx.activeBookingsCount} حجوزات نشطة. 
    آخر حجز له: ${ctx.latestBookingSummary}`;

  const history = (historyMessages || []).map(m => ({
    role: m.role === "bot" ? "assistant" : "user",
    content: m.content
  }));

  const reply = await callLLM({ systemPrompt, userMessage: userQuestion, history });

  return { reply, source: "AI" };
}