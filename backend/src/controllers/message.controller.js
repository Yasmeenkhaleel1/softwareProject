// src/controllers/message.controller.js
import Conversation from "../models/conversation.model.js";
import Message from "../models/message.model.js";
import User from "../models/user/user.model.js";
import Booking from "../models/booking.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import { notifyUser } from "../services/push.service.js";

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

    let conversations = await Conversation.find({
      $or: [{ customer: userId }, { expert: userId }],
    })
      .sort({ updatedAt: -1 })
      .populate("customer", "name email profilePic role")
      .populate("expert", "name email profilePic role")
      .lean();

    const expertUserIds = [
      ...new Set(conversations.map((c) => c.expert?._id?.toString()).filter(Boolean)),
    ];

    const profiles = await ExpertProfile.find({
      userId: { $in: expertUserIds },
      status: "approved",
    })
      .select("userId name profileImageUrl")
      .lean();

    const profileByUserId = {};
    for (const p of profiles) profileByUserId[p.userId.toString()] = p;

    conversations = conversations.map((conv) => {
      if (conv.expert && conv.expert._id) {
        const expertId = conv.expert._id.toString();
        const prof = profileByUserId[expertId];
        if (prof) {
          conv.expert.name = prof.name || conv.expert.name;
          conv.expert.profilePic = prof.profileImageUrl || conv.expert.profilePic;
        }
      }
      return conv;
    });

    return res.json({ conversations });
  } catch (e) {
    console.error("❌ listMyConversations error:", e);
    return res.status(500).json({ message: "Server error", error: e.message });
  }
};

/**
 * POST /api/messages/conversations
 * - get-or-create للمحادثة بين customer & expert
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
      return res.status(403).json({ message: "Only CUSTOMER or EXPERT can start conversations." });
    }

    if (!customerId || !expertId) {
      return res.status(400).json({ message: "Missing expertId or customerId in request body." });
    }

    const [customer, expert] = await Promise.all([
      User.findById(customerId),
      User.findById(expertId),
    ]);
    if (!customer || !expert) {
      return res.status(404).json({ message: "User not found." });
    }

    const bookingExists = await Booking.exists({
      customer: customerId,
      expertUserId: expertId,
    });

    if (!bookingExists) {
      return res.status(403).json({
        message: "Messaging is allowed only between customers and experts who have at least one booking.",
      });
    }

    let conversation = await Conversation.findOne({
      customer: customerId,
      expert: expertId,
    });

    if (!conversation) {
      conversation = await Conversation.create({ customer: customerId, expert: expertId });
    }

    const conv = await Conversation.findById(conversation._id)
      .populate("customer", "name email profilePic role")
      .populate("expert", "name email profilePic role")
      .lean();

    if (conv.expert && conv.expert._id) {
      const prof = await ExpertProfile.findOne({
        userId: conv.expert._id,
        status: "approved",
      })
        .select("name profileImageUrl")
        .lean();

      if (prof) {
        conv.expert.name = prof.name || conv.expert.name;
        conv.expert.profilePic = prof.profileImageUrl || conv.expert.profilePic;
      }
    }

    return res.json({ conversation: conv });
  } catch (e) {
    console.error("❌ getOrCreateConversation error:", e);
    return res.status(500).json({ message: "Server error", error: e.message });
  }
};

/**
 * GET /api/messages/conversations/:conversationId/messages?limit=50
 * - يرجّع رسائل المحادثة
 * - ويعمل read/unread reset (بدون إرسال إشعارات)
 */
export const listMessagesForConversation = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conversationId } = req.params;
    const limit = Math.min(Number(req.query.limit || 50), 200);

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

    const now = new Date();
    await Message.updateMany(
      { conversation: conversationId, to: userId, readAt: null },
      { $set: { readAt: now } }
    );

    if (isCustomer) conversation.unreadForCustomer = 0;
    else if (isExpert) conversation.unreadForExpert = 0;

    await conversation.save();

    return res.json({ conversation, messages });
  } catch (e) {
    console.error("❌ listMessagesForConversation error:", e);
    return res.status(e.status || 500).json({ message: e.message });
  }
};

/**
 * POST /api/messages/conversations/:conversationId/messages
 * - إرسال رسالة + إرسال إشعار للمستقبل
 */
export const sendMessageInConversation = async (req, res) => {
  try {
    const userId = req.user.id;
    const { conversationId } = req.params;
    const { text, attachmentUrl, attachmentName, attachmentType, bookingId } = req.body || {};

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

    const to =
      conversation.customer?.toString() === userId
        ? conversation.expert
        : conversation.customer;

    let bookingRef = undefined;
    if (bookingId) {
      const booking = await Booking.findById(bookingId);
      if (booking) bookingRef = booking._id;
    }

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

    const preview =
      text?.toString().slice(0, 80) ||
      attachmentName ||
      (attachmentType ? `Attachment (${attachmentType})` : "Attachment");

    conversation.lastMessagePreview = preview;
    conversation.lastMessageAt = message.createdAt;
    conversation.lastMessageSender = userId;

    if (isCustomer) conversation.unreadForExpert = (conversation.unreadForExpert || 0) + 1;
    else if (isExpert) conversation.unreadForCustomer = (conversation.unreadForCustomer || 0) + 1;

    await conversation.save();

    // ✅ إشعار للمستقبل: رسالة جديدة (مكانه الصح)
   
try {
  const senderUser = await User.findById(userId).select("name email role").lean();

  let senderName = (senderUser?.name || "").trim();

  // لو المرسل Expert واسم الـ User فاضي → جيبيه من ExpertProfile
  if (!senderName && senderUser?.role === "EXPERT") {
    const prof = await ExpertProfile.findOne({ userId, status: "approved" })
      .select("name")
      .lean();
    senderName = (prof?.name || "").trim();
  }

  // fallback أخير: الإيميل قبل @
  if (!senderName) {
    senderName = (senderUser?.email || "Someone").split("@")[0];
  }

  await notifyUser(to, {
    title: "💬 New Message",
    body: `${senderName}: ${preview}`,
    data: {
      type: "NEW_MESSAGE",
      conversationId: String(conversation._id),
      messageId: String(message._id),
      fromUserId: String(userId),
      senderName, // ✅ اختياري مفيد للـ UI
    },
    link: `/messages/${conversation._id}`,
  });
} catch (e) {
  console.error("❌ notify message failed:", e.message);
}


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
    return res.status(e.status || 500).json({ message: e.message });
  }
};

/**
 * GET /api/messages/unread-count
 * - يرجع عدد الرسائل غير المقروءة للـ user الحالي (حسب unreadForCustomer / unreadForExpert)
 */
export const getUnreadMessagesCount = async (req, res) => {
  try {
    const userId = req.user.id;

    const convs = await Conversation.find({
      $or: [{ customer: userId }, { expert: userId }],
    })
      .select("customer expert unreadForCustomer unreadForExpert")
      .lean();

    let count = 0;
    for (const c of convs) {
      if (c.customer?.toString() === userId) count += Number(c.unreadForCustomer || 0);
      else if (c.expert?.toString() === userId) count += Number(c.unreadForExpert || 0);
    }

    return res.json({ count });
  } catch (e) {
    console.error("❌ getUnreadMessagesCount error:", e);
    return res.status(500).json({ message: "Server error", error: e.message });
  }
};

