// src/controllers/dispute.controller.js
import Dispute from "../models/dispute.model.js";
import Booking from "../models/booking.model.js";
import Payment from "../models/payment.model.js";
import { refundPayment } from "./payments.stripe.js"; // نستخدمه جوّا

// 🎯 0) قائمة الحجوزات التي يمكن للعميل عمل Dispute عليها
// GET /api/public/disputes/bookings
export async function listDisputableBookings(req, res) {
  try {
    const customerId = req.user.id;

    // 1) الحجوزات التي:
    //   - للعميل الحالي
    //   - حالتها منطقية لفتح نزاع
    //   - والدفع فيها CAPTURED
    const rawBookings = await Booking.find({
      customer: customerId,
      status: { $in: ["CONFIRMED", "COMPLETED", "NO_SHOW"] },
      "payment.status": "CAPTURED",
    })
      .select(
        "code status startAt endAt timezone payment.amount payment.currency serviceSnapshot expert"
      )
      .sort({ startAt: -1 })
      .lean();

    // 2) الحجوزات التي عليها Dispute مفتوح أصلاً (ما بدنا نعيد فتحها)
    const openDisputes = await Dispute.find({
      customer: customerId,
      status: { $in: ["OPEN", "UNDER_REVIEW"] },
    })
      .select("booking")
      .lean();

    const blockedIds = new Set(
      openDisputes.map((d) => String(d.booking))
    );

    const bookings = rawBookings.filter(
      (b) => !blockedIds.has(String(b._id))
    );

    return res.json({ bookings });
  } catch (err) {
    console.error("listDisputableBookings error", err);
    res.status(500).json({ message: err.message });
  }
}

// 🎯 1) الكستمر يفتح Dispute
// POST /api/public/disputes
// 🎯 1) الكستمر يفتح Dispute
// POST /api/public/disputes
export async function createDispute(req, res) {
  try {
    const customerId = req.user.id; // لازم يكون CUSTOMER

    // 🔹 هنا أضفنا attachments
    const { bookingId, type, message, attachments } = req.body || {};

    if (!bookingId || !message) {
      return res
        .status(400)
        .json({ message: "bookingId and message are required" });
    }

    // نتأكد إنها Array من سترنجات (روابط)
    const safeAttachments = Array.isArray(attachments)
      ? attachments.filter((x) => typeof x === "string" && x.trim() !== "")
      : [];

    const booking = await Booking.findById(bookingId).lean();
    if (!booking) return res.status(404).json({ message: "Booking not found" });

    if (String(booking.customer) !== String(customerId)) {
      return res
        .status(403)
        .json({ message: "You can dispute only your own bookings" });
    }

    if (!booking.payment || !booking.payment.status) {
      return res
        .status(400)
        .json({ message: "This booking has no payment attached" });
    }

    const payment = await Payment.findOne({ booking: booking._id }).lean();
    if (!payment || payment.status !== "CAPTURED") {
      return res
        .status(400)
        .json({ message: "You can dispute only captured payments" });
    }

    // لو فيه Dispute مفتوح بالفعل لنفس الحجز → منع التكرار
    const existing = await Dispute.findOne({
      booking: booking._id,
      customer: customerId,
      status: { $in: ["OPEN", "UNDER_REVIEW"] },
    }).lean();

    if (existing) {
      return res.status(409).json({
        message: "You already opened a dispute for this booking",
        disputeId: existing._id,
      });
    }

    const dispute = await Dispute.create({
      booking: booking._id,
      payment: payment._id,
      customer: customerId,
      expert: booking.expertUserId,
      type: type || "OTHER",
      customerMessage: message,
      attachments: safeAttachments,   // 🟣✨ هنا نخزن الروابط
    });

    await Payment.findByIdAndUpdate(payment._id, {
      lastDisputeStatus: "OPEN",
      $push: {
        timeline: {
          action: "DISPUTE_OPENED",
          by: "CUSTOMER",
          at: new Date(),
          meta: { disputeId: dispute._id },
        },
      },
    });

    return res.status(201).json({ dispute });
  } catch (err) {
    console.error("createDispute error", err);
    return res.status(500).json({ message: err.message });
  }
}


// 🎯 2) الأدمن يشوف كل الـ Disputes
// GET /api/admin/disputes
export async function listDisputes(req, res) {
  try {
    const { status } = req.query;

    const match = {};
    if (status) match.status = status;

    const disputes = await Dispute.find(match)
      .populate("booking", "code status startAt")
      .populate("customer", "name email")
      .populate("expert", "name email")
      .populate("payment", "amount currency status")
      .sort({ createdAt: -1 });

    res.json({ disputes });
  } catch (err) {
    console.error("listDisputes error", err);
    res.status(500).json({ message: err.message });
  }
}

// 🎯 3) الأدمن يحسم النزاع + (اختياري) يعمل Refund
// PATCH /api/admin/disputes/:id/decision
export async function decideDispute(req, res) {
  try {
    const adminId = req.user.id; // لازم يكون ADMIN
    const { id } = req.params;
    const { resolution, refundAmount = 0, adminNotes } = req.body || {};

    const dispute = await Dispute.findById(id);
    if (!dispute) return res.status(404).json({ message: "Dispute not found" });

    const payment = await Payment.findById(dispute.payment);
    if (!payment) return res.status(404).json({ message: "Payment not found" });

    dispute.status =
      resolution === "REFUND_FULL" || resolution === "REFUND_PARTIAL"
        ? "RESOLVED_CUSTOMER"
        : "RESOLVED_EXPERT";

    dispute.resolution = resolution || "NONE";
    dispute.refundAmount = refundAmount || 0;
    dispute.adminNotes = adminNotes;
    dispute.decidedBy = adminId;
    dispute.decidedAt = new Date();
    await dispute.save();

    await Payment.findByIdAndUpdate(payment._id, {
      lastDisputeStatus: dispute.status,
      $push: {
        timeline: {
          action: "DISPUTE_DECIDED",
          by: "ADMIN",
          at: new Date(),
          meta: { resolution, refundAmount },
        },
      },
    });

    // لو القرار فيه Refund فعلي → نستخدم Stripe Refund
    if (resolution === "REFUND_FULL" || resolution === "REFUND_PARTIAL") {
      await refundPayment(
        {
          body: {
            paymentId: payment._id,
            amount:
              resolution === "REFUND_FULL" ? payment.amount : refundAmount,
          },
          user: { role: "ADMIN" },
        },
        {
          status: () => ({
            json: () => {},
          }),
          json: () => {},
        }
      );
    }

    return res.json({ dispute });
  } catch (err) {
    console.error("decideDispute error", err);
    res.status(500).json({ message: err.message });
  }
}
