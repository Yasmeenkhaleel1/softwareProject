import mongoose from "mongoose";

const PaymentSchema = new mongoose.Schema(
  {
    // 🎯 معلومات البطاقة (ليس ضروري دائماً لأن Stripe مخزّنها)
    holderName: { type: String, trim: true },
    cardLast4: { type: String, trim: true },
    brand: { type: String, trim: true }, // VISA/AMEX/MASTERCARD...
    expiry: { type: String, trim: true },

    // 🎯 معلومات الدفع الأساسية
    amount: { type: Number, required: true },     // إجمالي ما دفعه العميل
    currency: { type: String, default: "USD" },

    // 🎯 تقسيم المبلغ (بعد خصم العمولة)
    platformFee: { type: Number, default: 0 },    // نسبة المنصة 10% (أو حسب قرارك)
    netToExpert: { type: Number, default: 0 },    // صافي حصة الخبير
    refundedAmount: { type: Number, default: 0 }, // كم رجعنا للعميل (مهم لPartial Refund)

    txnId: { type: String, unique: true },        // Stripe PaymentIntent ID

    // 🎯 حالات الدفع (Escrow Flow)
    status: {
      type: String,
      enum: [
        "PENDING",        // لم يتم الدفع بعد
        "AUTHORIZED",     // دفع + محجوز المبلغ Auth
        "CAPTURED",       // تم التحصيل + الأموال جاهزة للخبير
        "REFUND_PENDING", // طلب استرجاع قيد التنفيذ
        "REFUNDED",       // اكتمل الاسترجاع
        "FAILED"
      ],
      default: "PENDING",
    },

    // 🔹 أهم نقطة: ربط دائم بالخبير عبر userId وليس ExpertProfileId
    customer: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
    expert: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // 🔥 هذا مهم وثابت ولا يتغير
    service: { type: mongoose.Schema.Types.ObjectId, ref: "Service" },
    booking: { type: mongoose.Schema.Types.ObjectId, ref: "bookings" },

    // 🧾 لتتبع أي Refund حدث (حتى لو كان متعدد)
    refunds: [
      {
        amount: Number,
        at: { type: Date, default: Date.now },
        stripeRefundId: String,
      }
    ],

    // 🟥 لو صار Dispute
    lastDisputeStatus: {
      type: String,
      enum: ["NONE", "OPEN", "UNDER_REVIEW", "RESOLVED_CUSTOMER", "RESOLVED_EXPERT"],
      default: "NONE",
    },

    // 🧭 سجل الأحداث مثل Dashboard Stripe
    timeline: [
      {
        at: { type: Date, default: Date.now },
        action: String, // AUTHORIZED, CAPTURED, REFUND, DISPUTE...
        by: String,     // STRIPE / SYSTEM / ADMIN
        meta: mongoose.Schema.Types.Mixed,
      },
    ]
  },
  { timestamps: true }
);

export default mongoose.model("payments", PaymentSchema);
