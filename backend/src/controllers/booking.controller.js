// src/controllers/booking.controller.js
import mongoose from "mongoose";
import Booking from "../models/booking.model.js";
import Payment from "../models/payment.model.js";
import Service from "../models/expert/service.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import { assertNoOverlap } from "../services/booking.service.js";

const NON_BLOCKING = new Set(["CANCELED", "REFUNDED"]);
const genCode = () =>
  `BK-${Math.random().toString(36).slice(2, 6).toUpperCase()}-${Date.now()
    .toString()
    .slice(-4)}`;

// ======================================================================
// 🎯 CREATE BOOKING
// ======================================================================
export async function createBookingPublic(req, res) {
  try {
    const {
      expertId,
      serviceId,
      startAt,
      endAt,
      timezone = "Asia/Hebron",
      customerNote = "",
      customerId,
      paymentId,
    } = req.body || {};

    if (!expertId || !serviceId || !startAt || !endAt || !customerId) {
      return res.status(400).json({
        message:
          "expertId, serviceId, customerId, startAt, endAt are required",
      });
    }

    if (
      !mongoose.Types.ObjectId.isValid(expertId) ||
      !mongoose.Types.ObjectId.isValid(serviceId) ||
      !mongoose.Types.ObjectId.isValid(customerId)
    ) {
      return res.status(400).json({ message: "Invalid IDs" });
    }

    const start = new Date(startAt);
    const end = new Date(endAt);
    if (isNaN(start) || isNaN(end) || start >= end) {
      return res.status(400).json({ message: "Invalid start/end" });
    }

    // Ensure expert is approved
    const profile = await ExpertProfile.findById(expertId)
      .select("status userId")
      .lean();

    if (!profile || profile.status !== "approved") {
      return res
        .status(404)
        .json({ message: "Expert not found or not approved" });
    }

    const expertUserId = profile.userId;

    // Ensure service belongs to expert
    const svc = await Service.findOne({
      _id: serviceId,
      expert: expertUserId,
      isPublished: true,
      status: "ACTIVE",
    })
      .select("title durationMinutes price currency")
      .lean();

    if (!svc) {
      return res.status(404).json({
        message: "Service not found or not active for this expert",
      });
    }

    const expectedMin =
      svc.durationMinutes || Math.round((end - start) / 60000);
    const actualMin = Math.round((end - start) / 60000);
    if (actualMin !== expectedMin) {
      return res.status(400).json({
        message: `Invalid slot duration. Expected ${expectedMin} minutes.`,
      });
    }

    // Availability check
    const Availability =
      (await import("../models/availability.model.js")).default;
    const av = await Availability.findOne({
      expert: expertId,
      status: "ACTIVE",
    }).lean();

    if (!av) {
      return res.status(400).json({
        message: "Expert has not set availability yet.",
      });
    }

    const dayOfWeek = start.getUTCDay();
    const activeDays = (av.rules || []).map((r) => r.dow);
    const dateStr = `${start.getUTCFullYear()}-${(start.getUTCMonth() + 1)
      .toString()
      .padStart(2, "0")}-${start.getUTCDate().toString().padStart(2, "0")}`;

    if (!activeDays.includes(dayOfWeek)) {
      return res.status(400).json({
        message: "❌ This day is not available for bookings.",
      });
    }

    // Check exceptions
    const exception = (av.exceptions || []).find((e) => e.date === dateStr);
    if (exception) {
      if (exception.off === true) {
        return res.status(400).json({
          message: "⚠️ This date is marked as a day off.",
        });
      }

      if (exception.windows && exception.windows.length > 0) {
        const toMinutes = (t) => {
          const [h, m] = t.split(":").map(Number);
          return h * 60 + m;
        };
        const startMin =
          start.getUTCHours() * 60 + start.getUTCMinutes();
        const endMin = end.getUTCHours() * 60 + end.getUTCMinutes();

        const withinWindow = exception.windows.some((w) => {
          const ws = toMinutes(w.start);
          const we = toMinutes(w.end);
          return startMin >= ws && endMin <= we;
        });

        if (!withinWindow) {
          return res.status(400).json({
            message:
              "⚠️ This time is outside the expert’s available windows.",
          });
        }
      }
    }

    // Overlap check
    await assertNoOverlap({
      expertId,
      startAt: start,
      endAt: end,
    });

    // Prevent duplicate booking
    const duplicate = await Booking.findOne({
      expert: expertId,
      customer: customerId,
      service: serviceId,
      startAt: start,
      status: { $nin: Array.from(NON_BLOCKING) },
    }).lean();

    if (duplicate) {
      return res
        .status(400)
        .json({ message: "You already have a booking for this slot." });
    }

    let paymentDoc = null;
    if (paymentId && mongoose.Types.ObjectId.isValid(paymentId)) {
      paymentDoc = await Payment.findById(paymentId).lean();
    }

    const booking = await Booking.create({
      code: genCode(),
      expert: expertId,
      expertUserId,
      customer: customerId,
      service: serviceId,
      serviceSnapshot: {
        title: svc.title,
        durationMinutes: expectedMin,
        price: svc.price || 0,
        currency: svc.currency || "USD",
      },
      startAt: start,
      endAt: end,
      timezone,
      status: "PENDING",
      customerNote,
      timeline: [
        { by: "CUSTOMER", action: "CREATED", at: new Date() },
        ...(paymentDoc
          ? [
              {
                by: "SYSTEM",
                action: "AUTHORIZED",
                at: new Date(),
                meta: { paymentId: paymentDoc._id },
              },
            ]
          : []),
      ],
      payment: paymentDoc
        ? {
            status: "AUTHORIZED",
            amount: paymentDoc.amount,
            currency: paymentDoc.currency,
            txnId: paymentDoc.txnId,
          }
        : {
            status: "PENDING",
            amount: svc.price || 0,
            currency: svc.currency || "USD",
          },
    });

    return res.status(201).json({
      message: "✅ Booking created successfully.",
      booking,
    });
  } catch (err) {
    console.error("❌ createBookingPublic error", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
}

// ======================================================================
// 🎯 GET CUSTOMER BOOKINGS
// ======================================================================
export async function getCustomerBookings(req, res) {
  try {
    const { customerId, status, from, to, page = 1, limit = 10 } = req.query;

    if (!customerId || !mongoose.Types.ObjectId.isValid(customerId)) {
      return res.status(400).json({ message: "Valid customerId required" });
    }

    const match = {
      customer: new mongoose.Types.ObjectId(customerId),
    };

    if (status) match.status = status;
    if (from || to) match.startAt = {};
    if (from) match.startAt.$gte = new Date(from);
    if (to) match.startAt.$lte = new Date(to);

    const query = Booking.find(match)
      .populate({
        path: "expert",
        select: "name specialization location status",
        model: "ExpertProfile",
      })
      .populate({
        path: "service",
        select: "title durationMinutes price currency",
      })
      .sort({ startAt: -1 })
      .skip((+page - 1) * +limit)
      .limit(+limit);

    const data = await query.lean();
    const total = await Booking.countDocuments(match);

    return res.json({
      success: true,
      total,
      page: +page,
      pages: Math.ceil(total / +limit),
      bookings: data.map((b) => ({
        id: b._id,
        code: b.code,
        status: b.status,
        startAt: b.startAt,
        endAt: b.endAt,
        timezone: b.timezone,
        service: b.service,
        expert: b.expert,
        payment: b.payment,
        customerNote: b.customerNote,
        createdAt: b.createdAt,
      })),
    });
  } catch (err) {
    console.error("getCustomerBookings error", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
}

// ======================================================================
// ⭐ RATE BOOKING + UPDATE SERVICE RATING + UPDATE EXPERT RATING
// ======================================================================
export async function rateBooking(req, res) {
  try {
    const { id } = req.params; // booking id
    const { rating } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ message: "Rating must be 1–5" });
    }

    // 1) Update booking
    const booking = await Booking.findById(id);
    if (!booking) return res.status(404).json({ message: "Booking not found" });

    booking.customerRating = rating;
    await booking.save();

    // 2) Update Service rating
    const service = await Service.findById(booking.service);
    if (!service) return res.status(404).json({ message: "Service not found" });

    const oldCount = service.ratingCount || 0;
    const oldTotal = (service.ratingAvg || 0) * oldCount;

    const newCount = oldCount + 1;
    const newAvg = (oldTotal + rating) / newCount;

    service.ratingCount = newCount;
    service.ratingAvg = newAvg;
    await service.save();

    // 3) Update ExpertProfile rating = avg of all service ratings
    const services = await Service.find({ expert: service.expert });

    const sum = services.reduce((acc, s) => acc + (s.ratingAvg || 0), 0);
    const avgOfExpert = sum / services.length;

    await ExpertProfile.findByIdAndUpdate(
      booking.expert,
      { ratingAvg: avgOfExpert },
      { new: true }
    );

    return res.json({
      message: "Rating submitted",
      booking,
    });
  } catch (err) {
    console.error("rateBooking error:", err);
    return res.status(500).json({
      message: "Server error",
      error: err.toString(),
    });
  }
}
