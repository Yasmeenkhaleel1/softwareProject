// src/models/message/message.model.js
import mongoose from "mongoose";

/**
 * Message:
 * - مرتبطة بـ Conversation
 * - from / to: Users
 * - ممكن نربطها بحجز معيّن (اختياري)
 * - تدعم نص + مرفق (ملف / صورة / PDF ...)
 */
const MessageSchema = new mongoose.Schema(
  {
    conversation: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Conversation",
      required: true,
      index: true,
    },

    from: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    to: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // 📝 نص الرسالة
    text: { type: String, trim: true },

    // 📎 مرفقات (URL جاهز من upload.routes)
    attachmentUrl: { type: String, trim: true },
    attachmentName: { type: String, trim: true },
    attachmentType: { type: String, trim: true }, // e.g: "image", "pdf", "doc"

    // 🔗 ربط اختياري بحجز معيّن (يفيد لو الشات داخل booking)
    booking: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "bookings", // نفس اسم الـ model في booking.model.js
    },

    // 👁️ وقت قراءة الرسالة (اختياري)
    readAt: { type: Date },
  },
  { timestamps: true }
);

MessageSchema.index({ conversation: 1, createdAt: 1 });

export default mongoose.model("Message", MessageSchema);
