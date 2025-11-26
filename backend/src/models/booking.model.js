// src/models/booking.model.js
import mongoose from "mongoose";

const BookingTimelineSchema = new mongoose.Schema(
  {
    at: { type: Date, default: () => new Date() },
    by: {
      type: String,
      enum: ["SYSTEM", "EXPERT", "CUSTOMER", "ADMIN"],
      required: true,
    },
    action: { type: String, required: true }, // CREATED, CONFIRMED, ...
    meta: { type: Object },
  },
  { _id: false }
);

const BookingSchema = new mongoose.Schema(
  {
    code: { type: String, index: true, unique: true },

    // 👇 لا نلمسه: يبقى ربط مباشر مع ExpertProfile (للتوافق مع الموجود)
    expert: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "ExpertProfile",
      required: true,
      index: true,
    },

    // 🆕 ربط ثابت مع صاحب الحساب (الخبير نفسه)
    // ليس required حتى لا يكسر البيانات القديمة
    expertUserId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      index: true,
    },

    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    service: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Service",
      required: true,
    },

    serviceSnapshot: {
      title: String,
      durationMinutes: Number,
      price: Number,
      currency: { type: String, default: "USD" },
    },

    startAt: { type: Date, required: true, index: true }, // UTC
    endAt: { type: Date, required: true, index: true }, // UTC
    timezone: { type: String, default: "Asia/Hebron" },

    status: {
      type: String,
      enum: [
        "PENDING",
        "CONFIRMED",
        "IN_PROGRESS",
        "COMPLETED",
        "CANCELED",
        "NO_SHOW",
        "REFUND_REQUESTED",
        "REFUNDED",
      ],
      default: "PENDING",
      index: true,
    },

    payment: {
      status: {
        type: String,
        enum: [
          "PENDING",
          "AUTHORIZED",
          "CAPTURED",
          "REFUNDED",
          "PARTIAL_REFUND",
        ],
        default: "PENDING",
        index: true,
      },
      amount: Number,
      currency: { type: String, default: "USD" },
      platformFee: { type: Number, default: 0 },
      netToExpert: { type: Number, default: 0 },
      txnId: String,
    },

    policy: {
      rescheduleBeforeHours: { type: Number, default: 24 },
      cancelBeforeHours: { type: Number, default: 24 },
      noShowPenalty: { type: Number, default: 1.0 }, // 100%
    },

    notes: String,
    customerNote: String,

    timeline: { type: [BookingTimelineSchema], default: [] },
  },
  { timestamps: true }
);

// فهارس
BookingSchema.index({ expert: 1, startAt: 1, endAt: 1, status: 1 });
BookingSchema.index({
  expertUserId: 1,
  startAt: 1,
  endAt: 1,
  status: 1,
});

export default mongoose.model("bookings", BookingSchema);
