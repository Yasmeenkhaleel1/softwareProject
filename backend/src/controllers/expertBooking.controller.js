// src/controllers/expertBooking.controller.js
import Booking from "../models/booking.model.js";
import Service from "../models/expert/service.model.js";
import { nextBookingCode } from "../utils/codes.js";
import Payment from "../models/payment.model.js";
import { ensureOwnership } from "../utils/ownership.js"

import { createZoomMeeting } from "../services/zoom.service.js";



import mongoose from "mongoose";
import {
  assertNoOverlap,
  canReschedule,
  canCancel,
} from "../services/booking.service.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

import Stripe from "stripe";
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// ✅ نستخدمها فقط عندما نحتاج ID للبروفايل الحالي
async function getExpertProfileId(userId) {
  const p = await ExpertProfile.findOne({
    userId: new mongoose.Types.ObjectId(userId),
    status: { $in: ["approved", "pending", "draft"] },
  }).lean();

  if (!p) {
    const err = new Error("Expert profile not found");
    err.status = 404;
    throw err;
  }
  return p._id;
}



// ===================== قائمة الحجوزات =====================
export const listBookings = async (req, res) => {
  const userId = req.user.id;
  const { status, from, to, page = 1, limit = 10 } = req.query;

  const match = {
    $or: [{ expertUserId: new mongoose.Types.ObjectId(userId) }],
  };

  if (status) match.status = status;
  if (from || to) match.startAt = {};
  if (from) match.startAt.$gte = new Date(from);
  if (to) match.startAt.$lte = new Date(to);

  const query = Booking.find(match)
    .populate("customer", "name email profilePic ")
    .populate("service", "title durationMinutes")
    .sort({ startAt: 1 })
    .skip((+page - 1) * +limit)
    .limit(+limit);

  const data = await query.lean();
  const total = await Booking.countDocuments(match);

  res.json({
    data,
    total,
    page: +page,
    pages: Math.ceil(total / +limit),
  });
};

// ===================== حجز واحد =====================
export const getBooking = async (req, res) => {
  const userId = req.user.id;
  const booking = await Booking.findById(req.params.id)
    .populate("customer", "name email profilePic ")
    .populate("service")
    .lean();

  ensureOwnership(booking, userId);
  res.json({ booking });
};

// ===================== إنشاء حجز (للاختبار) =====================
export const createBooking = async (req, res) => {
  try {
    //ُ مخصص عادة للعميل، لكن مؤقتًا للخبير
    const expertId = await getExpertProfileId(req.user.id);
    const { customerId, serviceId, startAtIso, timezone } = req.body;

    // 🔹 جلب الخدمة والتحقق من وجودها
    const service = await Service.findById(serviceId).lean();
    if (!service)
      return res.status(400).json({ error: "Service not found" });

    // ✅ التحقق أن الخدمة فعلاً تابعة لهذا الخبير
   if (String(service.expert) !== String(req.user.id)) {
  return res.status(403).json({
    error: "You cannot book a service that does not belong to your account."
  });
}


    const startAt = new Date(startAtIso);
    const endAt = new Date(startAt.getTime() + (service.durationMinutes || 60) * 60000);

    // 🔹 التأكد من عدم وجود تضارب زمني
    await assertNoOverlap({ expertId, startAt, endAt });

    // 🔹 تأكد أنه ما في حجز مكرر لنفس العميل والخدمة في نفس الوقت
const existing = await Booking.findOne({
  customer: customerId,
  service: serviceId,
  startAt: new Date(startAtIso),
  status: { $in: ["PENDING", "CONFIRMED", "IN_PROGRESS"] },
});

if (existing) {
  return res.status(400).json({
    error: "You already have a booking for this service at this time.",
  });
}

    // 🔹 إنشاء الحجز الجديد
    const doc = await Booking.create({
      code: nextBookingCode(),
      expert: expertId,
      expertUserId: req.user.id,
      customer: customerId,
      service: serviceId,
      serviceSnapshot: {
        title: service.title,
        durationMinutes: service.durationMinutes,
        price: service.price,
        currency: service.currency || "USD",
      },
      startAt,
      endAt,
      timezone: timezone || "Asia/Hebron",
      status: "PENDING",
      payment: {
        status: "PENDING",
        amount: service.price,
        currency: service.currency || "USD",
      },
      timeline: [{ by: "SYSTEM", action: "CREATED" }],
    });

    res.status(201).json({ booking: doc });
  } catch (err) {
    console.error("❌ createBooking error:", err);
    res.status(500).json({ error: err.message });
  }
};

// ===================== باقي العمليات =====================

// ===================== ACCEPT BOOKING = CAPTURE PAYMENT =====================

export const acceptBooking = async (req, res) => {
  try {
    const userId = req.user.id;
    const bookingId = req.params.id;

    const booking = await Booking.findById(bookingId);
    if (!booking) return res.status(404).json({ error: "Booking not found." });

    ensureOwnership(booking, userId);

    if (booking.status !== "PENDING") {
      return res
        .status(400)
        .json({ error: "Only PENDING bookings can be accepted." });
    }

    const payment = await Payment.findOne({ booking: booking._id });
    if (!payment)
      return res
        .status(402)
        .json({ error: "No payment found for this booking." });

    // 🔥 منع تكرار Capture في حال تمت العملية مسبقاً
    if (payment.status === "CAPTURED") {
      return res
        .status(409)
        .json({ error: "Payment already captured previously." });
    }

    if (payment.status !== "AUTHORIZED") {
      return res.status(402).json({
        error: "Payment must be AUTHORIZED before acceptance.",
      });
    }

    // =================== 💳 Stripe Capture ====================
    const stripePayment = await stripe.paymentIntents.capture(payment.txnId);

    payment.status = "CAPTURED";
    payment.capturedAt = new Date();
    payment.timeline.push({
      action: "CAPTURED",
      by: "EXPERT_ACCEPT",
      at: new Date(),
      meta: { stripe: stripePayment.id },
    });
    await payment.save();

    booking.status = "CONFIRMED";
    booking.payment.status = "CAPTURED";
    booking.payment.netToExpert = booking.payment.amount * 0.9; // (10% platform cut)
    booking.timeline.push({
      by: "EXPERT",
      action: "CONFIRMED",
      at: new Date(),
    });

    // =================== 🎥 Zoom Meeting (لا نكسر الحجز لو فشل) ====================
    try {
      const topic =
        booking.serviceSnapshot?.title
          ? `Session: ${booking.serviceSnapshot.title} (${booking.code})`
          : `Booking ${booking.code}`;

      const zoomMeeting = await createZoomMeeting({
        topic,
        startTime: booking.startAt,
        durationMinutes: booking.serviceSnapshot?.durationMinutes || 60,
        timezone: booking.timezone || process.env.ZOOM_DEFAULT_TIMEZONE || "Asia/Hebron",
      });

      booking.meeting = {
        provider: "ZOOM",
        joinUrl: zoomMeeting.joinUrl,
        startUrl: zoomMeeting.startUrl,
        meetingId: zoomMeeting.meetingId,
      };

      booking.timeline.push({
        by: "SYSTEM",
        action: "MEETING_CREATED",
        at: new Date(),
        meta: {
          provider: "ZOOM",
          meetingId: zoomMeeting.meetingId,
        },
      });
    } catch (zoomErr) {
      console.error("⚠ Zoom meeting creation failed", zoomErr);
      booking.timeline.push({
        by: "SYSTEM",
        action: "MEETING_CREATE_FAILED",
        at: new Date(),
        meta: {
          provider: "ZOOM",
          message: zoomErr.message,
        },
      });
      // ❗ المهم: ما نرمي error هنا عشان ما نخرب قبول الحجز
    }

    await booking.save();

  
    return res.json({
      success: true,
      message:
        "✔ Booking confirmed, payment captured, and Zoom meeting created (if possible)",
      booking,
    });
  } catch (err) {
    console.error("❌ acceptBooking error", err);
    res.status(500).json({ error: err.message });
  }
};





export const declineBooking = async (req, res) => {
  try {
    const userId = req.user.id;
    const booking = await Booking.findById(req.params.id);
    ensureOwnership(booking, userId);

    if (booking.status !== "PENDING")
      return res.status(400).json({ error: "Only PENDING bookings can be declined." });

    const payment = await Payment.findOne({ booking: booking._id });

    // 🔥 لو يوجد دفع AUTHORIZED → Cancel via Stripe
    if (payment && payment.status === "AUTHORIZED") {
      await stripe.paymentIntents.cancel(payment.txnId);
      payment.status = "CANCELED";
      payment.timeline.push({ action: "CANCELED_BEFORE_CONFIRM", at: new Date() });
      await payment.save();
    }

    booking.status = "CANCELED";
    booking.timeline.push({ by: "EXPERT", action: "DECLINED" });
    await booking.save();

 

    res.json({ success: true, message: "❌ Booking declined & payment reversed if present", booking });

  } catch (err) {
    res.status(500).json({ error: err.message });
  }
};


export const rescheduleBooking = async (req, res) => {
  const userId = req.user.id;
  const { startAtIso } = req.body;
  const booking = await Booking.findById(req.params.id);
  ensureOwnership(booking, userId);

  await canReschedule(booking);

  const newStart = new Date(startAtIso);
  const newEnd = new Date(
    newStart.getTime() +
      (booking.serviceSnapshot?.durationMinutes || 60) * 60000
  );

  await assertNoOverlap({
    expertId: userId,
    startAt: newStart,
    endAt: newEnd,
    excludeId: booking._id,
  });

  booking.startAt = newStart;
  booking.endAt = newEnd;
  booking.timeline.push({
    by: "EXPERT",
    action: "RESCHEDULED",
    meta: { to: newStart },
  });
  await booking.save();

  res.json({ booking });
};

export const startBooking = async (req, res) => {
  const userId = req.user.id;
  const booking = await Booking.findById(req.params.id);
  ensureOwnership(booking, userId);

  if (booking.status !== "CONFIRMED")
    return res
      .status(400)
      .json({ error: "Only CONFIRMED can start" });

  booking.status = "IN_PROGRESS";
  booking.timeline.push({ by: "EXPERT", action: "STARTED" });
  await booking.save();

  res.json({ booking });
};

export const completeBooking = async (req, res) => {
  const userId = req.user.id;
  const booking = await Booking.findById(req.params.id);
  ensureOwnership(booking, userId);

  if (booking.status !== "IN_PROGRESS")
    return res
      .status(400)
      .json({ error: "Only IN_PROGRESS can complete" });

  booking.status = "COMPLETED";
  if (booking.payment.status === "AUTHORIZED") {
    booking.payment.status = "CAPTURED";
  }
  booking.timeline.push({ by: "EXPERT", action: "COMPLETED" });
  await booking.save();

  res.json({ booking });
};

export const cancelBooking = async (req, res) => {
  const userId = req.user.id;
  const { reason } = req.body || {};
  const booking = await Booking.findById(req.params.id);
  ensureOwnership(booking, userId);

  await canCancel(booking);

  if (
    ["COMPLETED", "CANCELED", "NO_SHOW"].includes(booking.status)
  ) {
    return res
      .status(400)
      .json({ error: "Cannot cancel at this stage" });
  }

  booking.status = "CANCELED";
  booking.timeline.push({
    by: "EXPERT",
    action: "CANCELED",
    meta: { reason },
  });
  await booking.save();

  res.json({ booking });
};

export const markNoShow = async (req, res) => {
  const userId = req.user.id;
  const booking = await Booking.findById(req.params.id);
  ensureOwnership(booking, userId);

  if (!["CONFIRMED", "IN_PROGRESS"].includes(booking.status))
    return res.status(400).json({ error: "Invalid state" });

  booking.status = "NO_SHOW";
  booking.timeline.push({ by: "EXPERT", action: "NO_SHOW" });
  await booking.save();

  res.json({ booking });
};

export const overviewStats = async (req, res) => {
  const userId = req.user.id;
  const { from, to } = req.query;

  const match = {
    $or: [{ expertUserId: new mongoose.Types.ObjectId(userId) }],
  };

  if (from || to) match.startAt = {};
  if (from) match.startAt.$gte = new Date(from);
  if (to) match.startAt.$lte = new Date(to);

  const data = await Booking.aggregate([
    { $match: match },
    {
      $group: {
        _id: "$status",
        count: { $sum: 1 },
        totalPaid: {
          $sum: {
            $cond: [
              { $eq: ["$payment.status", "CAPTURED"] },
              "$payment.amount",
              0,
            ],
          },
        },
      },
    },
  ]);

  res.json({ data });
};

// ===================== Set / Update Meeting Link (Zoom) =====================
export const setMeetingLink = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { meetingUrl, provider = "ZOOM" } = req.body || {};

    if (!meetingUrl) {
      return res.status(400).json({ error: "meetingUrl is required" });
    }

    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ error: "Booking not found" });
    }

    ensureOwnership(booking, userId);

    booking.meeting = {
      provider,
      joinUrl: meetingUrl,
    };

    await booking.save();

    return res.json({
      success: true,
      message: "Meeting link updated",
      meeting: booking.meeting,
    });
  } catch (err) {
    console.error("setMeetingLink error", err);
    res.status(500).json({ error: err.message });
  }
};


// ===== Dashboard cards =====
export const dashboardStats = async (req, res) => {
  try {
    const userId = req.user.id;
    const expertObjectId = new mongoose.Types.ObjectId(userId);

    // ===== 1) إحصائيات أساسية =====
    const totalServices = await Service.countDocuments({
      expert: expertObjectId,
    });

    const bookingMatch = {
      $or: [{ expertUserId: expertObjectId }],
    };

    const totalBookings = await Booking.countDocuments(bookingMatch);
    const totalClients = (
      await Booking.distinct("customer", bookingMatch)
    ).length;

    // ===== 2) حساب قيمة الـ Wallet (صافي أرباح الخبير) =====
    const payments = await Payment.find({
      expert: expertObjectId,
      status: "CAPTURED", // فقط المدفوعات المحصَّلة فعلياً
    }).select("netToExpert refundedAmount status");

    let wallet = 0;

    for (const p of payments) {
      // لو حابة تحسبيها ببساطة = مجموع netToExpert
      // بدون خصم Refunds ممكن تخليها:
      // wallet += p.netToExpert || 0;

      const net = p.netToExpert || 0;
      const refunded = p.refundedAmount || 0;

      // 🔹 رصيد الدفعة = صافي للخبير - ما تم رده
      wallet += Math.max(net - refunded, 0);
    }

    return res.json({
      services: totalServices,
      bookings: totalBookings,
      clients: totalClients,
      wallet, // 🔥 هذه القيمة اللي حنستخدمها في Flutter
    });
  } catch (err) {
    console.error("dashboardStats error:", err);
    return res.status(500).json({ error: err.message });
  }
};

