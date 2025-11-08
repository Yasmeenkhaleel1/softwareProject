import Booking from "../models/booking.model.js";
import Payment from "../models/payment.model.js";

// Try to load a Service model. First, your expert folder; then fallback.
let Service = null;
try {
  const mod = await import("../models/expert/service.model.js");
  Service = mod.default;
} catch (_) {
  try {
    const mod2 = await import("../models/service.model.js");
    Service = mod2.default;
  } catch (_) {}
}

const NON_BLOCKING = new Set(["CANCELED", "REFUNDED"]);
const rangesOverlap = (aStart, aEnd, bStart, bEnd) => (aStart < bEnd && bStart < aEnd);
const genCode = () => `BK-${Math.random().toString(36).slice(2, 6).toUpperCase()}-${Date.now().toString().slice(-4)}`;

export async function createBookingPublic(req, res) {
  try {
    const {
      expert, service, startAt, endAt,
      timezone = "Asia/Hebron",
      customerNote = "",
      customer,             // required if auth disabled
      paymentId             // optional
    } = req.body;

    if (!customer) {
      return res.status(400).json({ message: "customer is required (ObjectId) when auth is disabled" });
    }
    if (!expert || !service || !startAt || !endAt) {
      return res.status(400).json({ message: "expert, service, startAt, endAt are required" });
    }

    const start = new Date(startAt);
    const end = new Date(endAt);
    if (isNaN(start) || isNaN(end) || start >= end) {
      return res.status(400).json({ message: "Invalid start/end" });
    }

    // Snapshot from Service (if model exists)
    let svc = null;
    if (Service) {
      svc = await Service.findById(service).select("title durationMinutes price currency").lean();
      if (!svc) return res.status(404).json({ message: "Service not found" });
    } else {
      svc = {
        title: "Session",
        durationMinutes: Math.round((end - start) / 60000),
        price: 0,
        currency: "USD",
      };
    }

    // Conflict check
    const conflicts = await Booking.find({
      expert,
      status: { $nin: Array.from(NON_BLOCKING) },
      $or: [
        { startAt: { $lt: end }, endAt: { $gt: start } },
        { startAt: { $gte: start, $lt: end } },
        { endAt:   { $gt: start,  $lte: end } },
      ],
    }).select("_id startAt endAt status");

    if (conflicts.length) {
      return res.status(409).json({ message: "Time slot no longer available" });
    }

    // optional payment link
    let paymentDoc = null;
    if (paymentId) {
      try { paymentDoc = await Payment.findById(paymentId); } catch (_) {}
    }

    const doc = await Booking.create({
      code: genCode(),
      expert,
      customer,
      service,
      serviceSnapshot: {
        title: svc.title,
        durationMinutes: svc.durationMinutes || Math.round((end - start) / 60000),
        price: svc.price || 0,
        currency: svc.currency || "USD",
      },
      startAt: start,
      endAt: end,
      timezone,
      status: paymentDoc ? "CONFIRMED" : "PENDING",
      customerNote,
      timeline: [
        { by: "CUSTOMER", action: "CREATED", at: new Date() },
        ...(paymentDoc ? [{ by: "SYSTEM", action: "CONFIRMED", at: new Date(), meta: { paymentId } }] : []),
      ],
      payment: paymentDoc
        ? {
            status: "CAPTURED",
            amount: paymentDoc.amount,
            currency: paymentDoc.currency,
            platformFee: 0,
            netToExpert: paymentDoc.amount,
            txnId: paymentDoc.txnId,
          }
        : {
            status: "PENDING",
            amount: svc.price || 0,
            currency: svc.currency || "USD",
            platformFee: 0,
            netToExpert: 0,
          },
    });

    return res.status(201).json({ message: "Booking created", booking: doc });
  } catch (err) {
    console.error("createBookingPublic error", err);
    return res.status(500).json({ message: "Server error", error: err.message });
  }
}
