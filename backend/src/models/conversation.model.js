// src/models/message/conversation.model.js
import mongoose from "mongoose";

/**
 * Conversation:
 * محادثة واحدة بين:
 *  - customer (User)
 *  - expert   (User)
 * حتى لو في 10 حجوزات بينهم، تظل نفس الكونفرسيشن.
 */
const ConversationSchema = new mongoose.Schema(
  {
    // 👤 الزبون
    customer: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // 👨‍🏫 الخبير (User نفسه، مش ExpertProfile)
    expert: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true,
    },

    // 📌 ملخّص آخر رسالة (لليست المحادثات)
    lastMessagePreview: { type: String, trim: true },
    lastMessageAt: { type: Date },
    lastMessageSender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
    },

    // 🔔 عدّاد الرسائل غير المقروءة
    unreadForCustomer: { type: Number, default: 0 },
    unreadForExpert: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// 🔒 محادثة واحدة فقط لكل (customer, expert)
ConversationSchema.index(
  { customer: 1, expert: 1 },
  { unique: true }
);

export default mongoose.model("Conversation", ConversationSchema);
