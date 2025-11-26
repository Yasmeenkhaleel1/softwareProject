import mongoose from "mongoose";

const PaymentSchema = new mongoose.Schema(
  {
    // 🎯 معلومات البطاقة (المختصرة فقط)
    holderName: { type: String, trim: true },
    cardLast4: { type: String, trim: true },
    brand: { type: String, enum: ["VISA", "MASTERCARD", "AMEX", "CARD"], default: "CARD" },
    expiry: { type: String, trim: true }, // e.g. "03/30"

    // 🎯 معلومات المبلغ والدفع
    amount: { type: Number, required: true },
    currency: { type: String, default: "USD" },
    platformFee: { type: Number, default: 0 }, // عمولة المنصة
    netToExpert: { type: Number, default: 0 }, // صافي الخبير بعد الخصم
    txnId: { type: String, unique: true }, // رقم المعاملة الداخلي أو من مزود الدفع

    // 🎯 الحالة
    status: {
      type: String,
      enum: ["PENDING", "AUTHORIZED", "CAPTURED", "FAILED", "REFUNDED"],
      default: "PENDING",
    },

    // 🎯 العلاقات مع الكيانات الأخرى
    customer: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
    expert: { type: mongoose.Schema.Types.ObjectId, ref: "users" },
    service: { type: mongoose.Schema.Types.ObjectId, ref: "services" },
    booking: { type: mongoose.Schema.Types.ObjectId, ref: "bookings" },

    // 🎯 سجل الأحداث (مثل Stripe Dashboard)
    timeline: [
      {
        at: { type: Date, default: Date.now },
        action: String, // CREATED, AUTHORIZED, CAPTURED, FAILED, REFUNDED
        by: String,     // SYSTEM, GATEWAY, ADMIN
        meta: mongoose.Schema.Types.Mixed,
      },
    ],
  },
  { timestamps: true }
);

export default mongoose.model("payments", PaymentSchema);
