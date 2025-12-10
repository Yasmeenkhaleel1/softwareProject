// src/services/aiAssistant.service.js
import Booking from "../models/booking.model.js";
import Service from "../models/expert/service.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

/**
 * 🧠 1) Rules ثابتة للأسئلة الشائعة
 * - يرجع { answer, matched: true } إذا لقى Rule مناسب
 */
function applyRules(rawQuestion, context) {
  const q = (rawQuestion || "").toString().toLowerCase().trim();

  // مثال: أسئلة عن إلغاء الحجز
  const cancelKeywords = ["cancel booking", "الغاء الحجز", "إلغاء الحجز", "cancel my session"];
  if (cancelKeywords.some((k) => q.includes(k))) {
    const hasActive = context.activeBookingsCount > 0;
    return {
      matched: true,
      answer:
        "📌 **إلغاء الحجز**\n\n" +
        "- يمكنك إلغاء الحجز من صفحة *My Bookings* داخل المنصّة.\n" +
        "- الحجز الذي حالته `PENDING` أو `CONFIRMED` غالبًا يمكن إلغاؤه حسب سياسة كل خبير.\n" +
        (hasActive
          ? `- حاليًا لديك ${context.activeBookingsCount} حجز/حجوزات فعّالة، بإمكانك الدخول إليها واختيار الحجز الذي تريد إلغاءه.\n`
          : "- لا يوجد لديك حجوزات فعّالة حاليًا.\n") +
        "\n⚠ في بعض الحالات قد لا يكون الإلغاء متاحًا إذا كان موعد الجلسة قريب جدًا من وقتها المحدد."
    };
  }

  // مثال: أسئلة عن حالات الحجز (status)
  const statusKeywords = [
    "what does pending mean",
    "pending booking",
    "معنى pending",
    "ما معنى كونفرمد",
    "confirmed booking",
    "حالة الحجز",
    "complate",
    "pending",
    "confirmed",
    "in_progress"
  ];
  if (statusKeywords.some((k) => q.includes(k))) {
    return {
      matched: true,
      answer:
        "📌 **معاني حالات الحجز:**\n\n" +
        "- `PENDING`: تم إرسال طلب الحجز ويحتاج موافقة الخبير.\n" +
        "- `CONFIRMED`: الخبير وافق على الحجز وتم تأكيد الموعد.\n" +
        "- `IN_PROGRESS`: الجلسة جارية الآن أو بدأت.\n" +
        "- `COMPLETED`: تم إنهاء الجلسة بنجاح.\n" +
        "- `CANCELED`: تم إلغاء الحجز قبل موعده.\n" +
        "- `NO_SHOW`: لم يحضر أحد الطرفين الجلسة في موعدها.\n"
    };
  }

  // مثال: أسئلة عن الدفع
  const paymentKeywords = [
    "payment",
    "stripe",
    "pay",
    "ادفع",
    "الدفع",
    "الفلوس",
    "بطاقة",
    "visa"
  ];
  if (paymentKeywords.some((k) => q.includes(k))) {
    return {
      matched: true,
      answer:
        "💳 **الدفع في المنصّة**\n\n" +
        "- نحن نستخدم نظام دفع آمن عبر مزوّد خارجي (Stripe أو ما شابهه).\n" +
        "- يتم خصم قيمة الجلسة عند تأكيد عملية الدفع، ثم يتم *تجميد المبلغ* حتى يقوم الخبير بقبول الحجز.\n" +
        "- عند قبول الحجز يتم *تأكيد الدفع (Capture)*، وعند رفضه يتم إلغاء العملية حسب سياسة المنصّة.\n" +
        "\n⚠ تأكد دائمًا من إدخال بيانات البطاقة بشكل صحيح واستخدام اتصال آمن."
    };
  }

  // مثال: أسئلة عن "أين أرى حجوزاتي؟"
  const myBookingsKeywords = [
    "where can i see my bookings",
    "my bookings",
    "حجوزاتي",
    "وين حجوزاتي",
    "عرض الحجوزات",
  ];
  if (myBookingsKeywords.some((k) => q.includes(k))) {
    return {
      matched: true,
      answer:
        "📆 **عرض الحجوزات الخاصة بك**\n\n" +
        "- يمكنك رؤية كل الحجوزات من صفحة *My Bookings* أو من صفحة التقويم في حساب الكستمر.\n" +
        "- من هناك تستطيع متابعة حالة كل حجز (PENDING / CONFIRMED / COMPLETED ...).\n" +
        "- كما يمكنك متابعة مواعيد الجلسات القادمة وتفاصيل كل خبير حجزت معه."
    };
  }

  // لا يوجد Rule مطابق
  return { matched: false, answer: null };
}

/**
 * 🧬 2) جلب Context بسيط من الداتابيس للكستمر
 * - آخر حجز
 * - عدد الحجوزات الفعّالة
 * - عدد كل الحجوزات
 */
export async function buildCustomerContext(userId) {
  const [latestBooking, activeCount, totalCount] = await Promise.all([
    Booking.findOne({ customer: userId })
      .sort({ startAt: -1 })
      .populate({
        path: "service",
        select: "title",
        model: Service,
      })
      .populate({
        path: "expert",
        select: "name specialization",
        model: ExpertProfile,
      })
      .lean(),
    Booking.countDocuments({
      customer: userId,
      status: { $in: ["PENDING", "CONFIRMED", "IN_PROGRESS"] },
    }),
    Booking.countDocuments({ customer: userId }),
  ]);

  let latestSummary = "No previous bookings.";
  if (latestBooking) {
    const s = latestBooking;
    const expertName = s.expert?.name || "Unknown expert";
    const serviceTitle =
      s.service?.title || s.serviceSnapshot?.title || "Service";
    latestSummary =
      `Last booking:\n` +
      `- Code: ${s.code}\n` +
      `- Status: ${s.status}\n` +
      `- Service: ${serviceTitle}\n` +
      `- Expert: ${expertName}\n` +
      `- Date: ${s.startAt?.toISOString?.() || ""}\n`;
  }

  return {
    activeBookingsCount: activeCount,
    totalBookingsCount: totalCount,
    latestBookingSummary: latestSummary,
  };
}

/**
 * 🧠 3) استدعاء نموذج الذكاء الاصطناعي (Placeholder)
 * - هنا تضيف Integration مع OpenAI / أي موديل آخر
 */
async function callLLM({ systemPrompt, userMessage, history, context }) {
  // ⚠️ Placeholder:
  // هنا بتحطي كود الاستدعاء الحقيقي لمزوّد الـ AI (OpenAI أو غيره)
  // وتستخدمي systemPrompt + history + userMessage + context ضمن prompt واحد.

  const fakeAnswer =
    "أنا مساعد المنصّة الذكي 🤖.\n" +
    "حالياً هذا رد تجريبي (Placeholder) من الـ Backend.\n" +
    "انتي ممكن تربطي هذا المكان مع أي API حقيقي للذكاء الاصطناعي لاحقًا.";

  return fakeAnswer;
}

/**
 * 🎯 4) الدالة الرئيسية لتوليد رد المساعد
 * - تحاول Rules أولاً
 * - لو فشلت → تستدعي نموذج AI مع Context من DB + History من AiSession
 */
export async function generateAssistantReply({
  userId,
  userQuestion,
  historyMessages,
}) {
  // 1) جهّزي Context من الداتابيس
  const ctx = await buildCustomerContext(userId);

  // 2) جرّبي الـ Rules
  const ruleResult = applyRules(userQuestion, ctx);
  if (ruleResult.matched) {
    return {
      reply: ruleResult.answer,
      source: "RULE",
      context: ctx,
    };
  }

  // 3) لو مافي Rule مطابق → نروح للـ AI
  const systemPrompt =
    "You are an AI assistant for an online booking platform that connects customers with experts. " +
    "You speak Arabic in a simple, clear way, but you can also use English terms for technical words (like status names). " +
    "You must always be honest about what the system can and cannot do. " +
    "Never promise features that do not exist. " +
    "Use the given CONTEXT about the user's bookings when answering.\n";

  // نحضّر History نصي بسيط (اختياري)
  const historyForModel = (historyMessages || []).map((m) => ({
    role: m.role,
    content: m.content,
  }));

  const contextText =
    `USER BOOKING CONTEXT:\n` +
    `- Active bookings: ${ctx.activeBookingsCount}\n` +
    `- Total bookings: ${ctx.totalBookingsCount}\n` +
    `${ctx.latestBookingSummary}\n`;

  const replyFromModel = await callLLM({
    systemPrompt,
    userMessage: userQuestion,
    history: historyForModel,
    context: contextText,
  });

  return {
    reply: replyFromModel,
    source: "AI",
    context: ctx,
  };
}
