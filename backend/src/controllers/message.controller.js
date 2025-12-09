// src/controllers/message.controller.js
import Conversation from "../models/conversation.model.js";
import Message from "../models/message.model.js";
import User from "../models/user/user.model.js";
import Booking from "../models/booking.model.js";

/**
 * Helper: يتأكد إن اليوزر جزء من المحادثة
 */
function ensureParticipant(conv, userId) {
  const isCustomer = conv.customer?.toString() === userId;
  const isExpert = conv.expert?.toString() === userId;
  if (!isCustomer && !isExpert) {
    const err = new Error("You are not a participant in this conversation.");
    err.status = 403;
    throw err;
  }
  return { isCustomer, isExpert };
}

/**
 * GET /api/messages/conversations
 * - يرجّع كل المحادثات الخاصة باليوزر الحالي (كـ customer أو expert)
 */
export const listMyConversations = async (req, res) => {
  try {
    const userId = req.user.id;

    const conversations = await Conversation.find({
      $or: [{ customer: userId }, { expert: userId }],
    })
      .sort({ updatedAt: -1 })
      .populate("customer", "name email profilePic role")
      .populate("expert", "name email profilePic role")
      .lean();

    return res.json({ conversations });
  } catch (e) {
    console.error("❌ listMyConversations error:", e);
    return res.status(500).json({ message: "Server error", error: e.message });
  }
};

/**
 * POST /api/messages/conversations
 * Body (لو اليوزر CUSTOMER):
 *   { expertId }
 * Body (لو اليوزر EXPERT):
 *   { customerId }
 *
 * - يعمل get-or-create لمحادثة بين customer & expert
 */
export const getOrCreateConversation = async (req, res) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    let customerId;
    let expertId;

    if (role === "CUSTOMER") {
      customerId = userId;
      expertId = req.body.expertId;
    } else if (role === "EXPERT") {
      expertId = userId;
      customerId = req.body.customerId;
    } else {
      return res
        .status(403)
        .json({ message: "Only CUSTOMER or EXPERT can start conversations." });
    }

    if (!customerId || !expertId) {
      return res.status(400).json({
        message: "Missing expertId or customerId in request body.",
      });
    }

    // ✅ تأكد إن اليوزرين موجودين
    const [customer, expert] = await Promise.all([
      User.findById(customerId),
      User.findById(expertId),
    ]);
    if (!customer || !expert) {
      return res.status(404).json({ message: "User not found." });
    }

    // ✅ جديد: لازم يكون بينهم حجز واحد على الأقل
    const bookingExists = await Booking.exists({
      customer: customerId,
      expertUserId: expertId,
    });

    if (!bookingExists) {
      return res.status(403).json({
        message:
          "Messaging is allowed only between customers and experts who have at least one booking.",
      });
    }

    // 🔁 نفس اللوجيك القديم: get-or-create للمحادثة
    let conversation = await Conversation.findOne({
      customer: customerId,
      expert: expertId,
    });

    if (!conversation) {
      conversation = await Conversation.create({
        customer: customerId,
        expert: expertId,
      });
    }

    const conv = await Conversation.findById(conversation._id)
      .populate("customer", "name email profilePic role")
      .populate("expert", "name email profilePic role");

    return res.json({ conversation: conv });
  } catch (e) {
    console.error("❌ getOrCreateConversation error:", e);
    return res.status(500).json({ message: "Server error", error: e.message });
  }
};


/**
 * GET /api/messages/conversations/:conversationId/messages?limit=50
 * - يرجّع رسائل المحادثة (بشكل افتراضي آخر 50 رسالة)
 * - يضمن إن اليوزر جزء من المحادثة
 */
export const listMessagesForConversation = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conversationId } = req.params;
    const limit = Math.min(
      Number(req.query.limit || 50),
      200
    ); // حماية بسيطة

    const conversation = await Conversation.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({ message: "Conversation not found." });
    }

    const { isCustomer, isExpert } = ensureParticipant(conversation, userId);

    const messages = await Message.find({ conversation: conversationId })
      .sort({ createdAt: 1 })
      .limit(limit)
      .populate("from", "name email profilePic role")
      .populate("to", "name email profilePic role")
      .lean();

    // تحديث الـ unread counter و readAt للرسائل اللي وصلت للمستخدم الحالي
    const now = new Date();
    await Message.updateMany(
      {
        conversation: conversationId,
        to: userId,
        readAt: null,
      },
      { $set: { readAt: now } }
    );

    if (isCustomer) {
      conversation.unreadForCustomer = 0;
    } else if (isExpert) {
      conversation.unreadForExpert = 0;
    }
    await conversation.save();

    return res.json({ conversation, messages });
  } catch (e) {
    console.error("❌ listMessagesForConversation error:", e);
    const status = e.status || 500;
    return res.status(status).json({ message: e.message });
  }
};

/**
 * POST /api/messages/conversations/:conversationId/messages
 * Body:
 *  {
 *    text?: string,
 *    attachmentUrl?: string,
 *    attachmentName?: string,
 *    attachmentType?: string,
 *    bookingId?: string (اختياري)
 *  }
 */
export const sendMessageInConversation = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conversationId } = req.params;
    const {
      text,
      attachmentUrl,
      attachmentName,
      attachmentType,
      bookingId,
    } = req.body || {};

    if (!text && !attachmentUrl) {
      return res.status(400).json({
        message: "Message must contain at least text or attachmentUrl.",
      });
    }

    const conversation = await Conversation.findById(conversationId);
    if (!conversation) {
      return res.status(404).json({ message: "Conversation not found." });
    }

    const { isCustomer, isExpert } = ensureParticipant(conversation, userId);

    // حدّد المستقبل
    const to =
      conversation.customer?.toString() === userId
        ? conversation.expert
        : conversation.customer;

    // لو فيه bookingId → تأكد إنه موجود (اختياري)
    let bookingRef = undefined;
    if (bookingId) {
      const booking = await Booking.findById(bookingId);
      if (booking) {
        bookingRef = booking._id;
      }
    }

    // إنشاء الرسالة
    const message = await Message.create({
      conversation: conversation._id,
      from: userId,
      to,
      text,
      attachmentUrl,
      attachmentName,
      attachmentType,
      booking: bookingRef,
    });

    // تحديث ملخّص المحادثة
    const preview =
      text?.toString().slice(0, 80) ||
      attachmentName ||
      (attachmentType ? `Attachment (${attachmentType})` : "Attachment");

    conversation.lastMessagePreview = preview;
    conversation.lastMessageAt = message.createdAt;
    conversation.lastMessageSender = userId;

    if (isCustomer) {
      conversation.unreadForExpert =
        (conversation.unreadForExpert || 0) + 1;
    } else if (isExpert) {
      conversation.unreadForCustomer =
        (conversation.unreadForCustomer || 0) + 1;
    }

    await conversation.save();

    const fullMessage = await Message.findById(message._id)
      .populate("from", "name email profilePic role")
      .populate("to", "name email profilePic role")
      .lean();

    return res.status(201).json({
      message: fullMessage,
      conversation,
    });
  } catch (e) {
    console.error("❌ sendMessageInConversation error:", e);
    const status = e.status || 500;
    return res.status(status).json({ message: e.message });
  }
};
