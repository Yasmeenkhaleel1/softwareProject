// src/models/dispute.model.js
import mongoose from "mongoose";

const disputeSchema = new mongoose.Schema(
  {
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "bookings",          // ✅ نفس اسم الموديل عندك
      required: true,
    },
    payment: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "payments",          // ✅ نفس اسم الموديل عندك
      required: true,
    },
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },
    expert: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // نوع المشكلة
    type: {
      type: String,
      enum: ["QUALITY", "NO_SHOW", "LATE", "OTHER"],
      default: "OTHER",
    },

    customerMessage: { type: String, trim: true },
    attachments: [{ type: String, trim: true }], // روابط صور/ملفات (اختياري)

    // حالة النزاع
    status: {
      type: String,
      enum: ["OPEN", "UNDER_REVIEW", "RESOLVED_CUSTOMER", "RESOLVED_EXPERT"],
      default: "OPEN",
      index: true,
    },

    // قرار الأدمن
    resolution: {
      // مثلاً REFUND_FULL, REFUND_PARTIAL, NO_REFUND
      type: String,
      enum: ["NONE", "REFUND_FULL", "REFUND_PARTIAL", "NO_REFUND"],
      default: "NONE",
    },
    refundAmount: { type: Number, default: 0 },

    adminNotes: { type: String, trim: true },
    decidedBy: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, // أدمن
    decidedAt: Date,
  },
  { timestamps: true }
);

// فهارس إضافية لتحسين الأداء
disputeSchema.index({ booking: 1 });
disputeSchema.index({ payment: 1 });

export default mongoose.model("Dispute", disputeSchema);
