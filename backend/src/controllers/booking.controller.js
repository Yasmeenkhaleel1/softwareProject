// src/controllers/booking.controller.js
// =============================================================
// 📌 src/controllers/booking.controller.js
// 🎯 Public Booking Creation (Customer → Expert)
// =============================================================

import mongoose from "mongoose";
import Booking from "../models/booking.model.js";
import Payment from "../models/payment.model.js";
import Service from "../models/expert/service.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import { assertNoOverlap } from "../services/booking.service.js";

import User from "../models/user/user.model.js";

import { updateExpertRatingByUserId } from "../services/expertRating.service.js";

import Stripe from "stripe";
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

// Days considered non-blocking (old bookings)
const NON_BLOCKING = new Set(["CANCELED", "REFUNDED"]);

// Unique booking code generator
const genCode = () =>
  `BK-${Math.random().toString(36).slice(2, 6).toUpperCase()}-${Date.now()
    .toString()
    .slice(-4)}`;


// =============================================================
// 🎯 createBookingPublic — Main Booking Endpoint
// POST /api/public/bookings
// =============================================================
export async function createBookingPublic(req, res) {
  try {
    // ---------------------------------------------------------
    // 1️⃣ Extract & validate inputs
    // ---------------------------------------------------------
    const {
      expertId,
      serviceId,
      customerId,
      startAt,
      endAt,
      timezone = "Asia/Hebron",
      customerNote = "",
      paymentId,
    } = req.body || {};

    if (!expertId || !serviceId || !customerId || !startAt || !endAt) {
      return res.status(400).json({
        message: "expertId, serviceId, customerId, startAt, endAt are required",
      });
    }

    // Validate IDs format
    const ids = [expertId, serviceId, customerId];
    if (ids.some((id) => !mongoose.Types.ObjectId.isValid(id))) {
      return res.status(400).json({ message: "Invalid ID format" });
    }

    const start = new Date(startAt);
    const end = new Date(endAt);

    if (isNaN(start) || isNaN(end) || start >= end) {
      return res.status(400).json({ message: "Invalid start/end timestamps" });
    }

    // ---------------------------------------------------------
    // 2️⃣ Validate Expert Profile (must be approved)
    // ---------------------------------------------------------
    const profile = await ExpertProfile.findById(expertId)
      .select("status userId")
      .lean();

    if (!profile || profile.status !== "approved") {
      return res
        .status(404)
        .json({ message: "Expert not found or not approved" });
    }

    const expertUserId = profile.userId;

    // ---------------------------------------------------------
    // 3️⃣ Validate Service belongs to this expert
    // ---------------------------------------------------------
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

    // ---------------------------------------------------------
    // 4️⃣ Validate Duration matches service rules
    // ---------------------------------------------------------
    const expectedMin =
      svc.durationMinutes || Math.round((end - start) / 60000);
    const actualMin = Math.round((end - start) / 60000);

    if (actualMin !== expectedMin) {
      return res.status(400).json({
        message: `Invalid slot duration. Expected ${expectedMin} minutes.`,
      });
    }

    // ---------------------------------------------------------
    // 5️⃣ Validate Availability (Active Rules + Exceptions)
    // ---------------------------------------------------------
    const Availability = (await import("../models/availability.model.js"))
      .default;

    const av = await Availability.findOne({
      expert: expertId,
      status: "ACTIVE",
    }).lean();

    if (!av) {
      return res
        .status(400)
        .json({ message: "Expert has not configured availability yet" });
    }

    const dayOfWeek = start.getUTCDay();
    const activeDays = (av.rules || []).map((r) => r.dow);

    const dateStr = `${start.getUTCFullYear()}-${(start.getUTCMonth() + 1)
      .toString()
      .padStart(2, "0")}-${start.getUTCDate().toString().padStart(2, "0")}`;

    // Not in weekly availability
    if (!activeDays.includes(dayOfWeek)) {
      return res.status(400).json({
        message: "This day is not available for bookings",
      });
    }

    // Check exceptions
    const exception = (av.exceptions || []).find((e) => e.date === dateStr);
    if (exception) {
      if (exception.off) {
        return res.status(400).json({
          message: "This date is marked as a day off",
        });
      }

      if (exception.windows?.length > 0) {
        const toMinutes = (t) => {
          const [h, m] = t.split(":").map(Number);
          return h * 60 + m;
        };

        const sMin = start.getUTCHours() * 60 + start.getUTCMinutes();
        const eMin = end.getUTCHours() * 60 + end.getUTCMinutes();

        const insideWindow = exception.windows.some((w) => {
          const ws = toMinutes(w.start);
          const we = toMinutes(w.end);
          return sMin >= ws && eMin <= we;
        });

        if (!insideWindow) {
          return res.status(400).json({
            message:
              "This time slot is outside the expert’s availability window",
          });
        }
      }
    }

    // ---------------------------------------------------------
    // 6️⃣ Prevent double-booking (time overlap check)
    // ---------------------------------------------------------
    await assertNoOverlap({
      expertId,
      startAt: start,
      endAt: end,
    });

    // ---------------------------------------------------------
    // 7️⃣ Prevent duplicate booking for same user/service/time
    // ---------------------------------------------------------
    const duplicate = await Booking.findOne({
      expert: expertId,
      customer: customerId,
      service: serviceId,
      startAt: start,
      status: { $nin: Array.from(NON_BLOCKING) },
    }).lean();

    if (duplicate) {
      return res.status(400).json({
        message: "You already have a booking for this slot",
      });
    }

    // ---------------------------------------------------------
    // 8️⃣ Load payment document (if exists)
    // ---------------------------------------------------------
    let paymentDoc = null;

    if (paymentId && mongoose.Types.ObjectId.isValid(paymentId)) {
      paymentDoc = await Payment.findById(paymentId).lean();
    }

    // ---------------------------------------------------------
    // 9️⃣ Create booking
    // ---------------------------------------------------------
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
            platformFee: 0,
            netToExpert: 0,
          }
        : {
            status: "PENDING",
            amount: svc.price || 0,
            currency: svc.currency || "USD",
            platformFee: 0,
            netToExpert: 0,
          },
    });

   
   
    // ---------------------------------------------------------
    // 🔟 Final Response
    // ---------------------------------------------------------
    return res.status(201).json({
      message: "Booking created successfully",
      booking,
    });
  } catch (err) {
    console.error("❌ createBookingPublic error", err);
    return res.status(500).json({
      message: "Server error",
      error: err.message,
    });
  }
}

/**
 * 🎯 GET /api/public/bookings?customerId=...
 * جلب جميع الحجوزات الخاصة بالكستمر
 */
export async function getCustomerBookings(req, res) {
  try {
    const { customerId, status, from, to, page = 1, limit = 10 } = req.query;

    // ✅ تحقق أن customerId موجود وصحيح
    if (!customerId || !mongoose.Types.ObjectId.isValid(customerId)) {
      return res.status(400).json({ message: "Valid customerId is required" });
    }

    const match = {
      customer: new mongoose.Types.ObjectId(customerId),
    };

    // ✅ فلترة بالحالة إذا موجودة
    if (status) match.status = status;

    // ✅ فلترة بالتاريخ إذا محددة
    if (from || to) match.startAt = {};
    if (from) match.startAt.$gte = new Date(from);
    if (to) match.startAt.$lte = new Date(to);

    // ✅ استعلام الحجوزات (مع populate للخبير والخدمة)
    const query = Booking.find(match)
      .populate({
        path: "expert",
        select: "name specialization location status profileImageUrl",
        model: "ExpertProfile",
      })
      .populate({
        path: "service",
        select: "title durationMinutes price currency",
      })
      .sort({ startAt: -1 }) // أحدث أولًا
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
        expertUserId: b.expertUserId, ///for messaging
        payment: b.payment,
        customerNote: b.customerNote,
        createdAt: b.createdAt,

          meeting: b.meeting,
          review: b.review,
      })),
    });
  } catch (err) {
    console.error("getCustomerBookings error", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
}

/**
 * 🎯 POST /api/customer/bookings/:id/review
 * العميل يضيف / يعدّل تقييمه بعد إتمام الجلسة
 */
export async function addCustomerReview(req, res) {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { rating, comment = "" } = req.body || {};

    if (!rating || rating < 1 || rating > 5) {
      return res
        .status(400)
        .json({ message: "rating must be between 1 and 5" });
    }

    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // 🔐 تأكد أن هذا هو صاحب الحجز
    if (String(booking.customer) !== String(userId)) {
      return res
        .status(403)
        .json({ message: "You can only review your own bookings" });
    }

    // ✅ فقط الحجوزات المكتملة
    if (booking.status !== "COMPLETED") {
      return res.status(400).json({
        message: "You can review only COMPLETED bookings",
      });
    }

    const now = new Date();

    booking.review = {
      rating,
      comment,
      createdAt: booking.review?.createdAt || now,
      updatedAt: now,
    };
    await booking.save();

    // 🔁 تحديث تقييم الخدمة نفسها (Service.ratingAvg)
    const service = await Service.findById(booking.service);
    if (service) {
      const existing = service.ratings.find(
        (r) => String(r.userId) === String(userId)
      );
      if (existing) {
        existing.value = rating;
      } else {
        service.ratings.push({ userId, value: rating });
        service.ratingCount = service.ratings.length;
      }

      const total = service.ratings.reduce((sum, r) => sum + r.value, 0);
      service.ratingAvg = total / (service.ratingCount || 1);

      await service.save();
      
      // ⭐️ مهم: حدّث Rating البروفايل ككل بناءً على كل الخدمات
      await updateExpertRatingByUserId(service.expert);
    }

    return res.json({
      success: true,
      message: "Review saved successfully",
      review: booking.review,
      ratingAvg: service?.ratingAvg,
    });
  } catch (err) {
    console.error("addCustomerReview error", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
}

/**
 * 🎯 POST /api/customer/bookings/:id/cancel
 * الكستمر يلغي حجزه (فقط لو PENDING)
 */
export async function cancelCustomerBooking(req, res) {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const booking = await Booking.findById(id);
    if (!booking) {
      return res.status(404).json({ message: "Booking not found" });
    }

    // 🔐 تأكد إنه صاحب الحجز
    if (String(booking.customer) !== String(userId)) {
      return res
        .status(403)
        .json({ message: "You can cancel only your own bookings" });
    }

    // ✅ فقط الحجوزات PENDING
    if (booking.status !== "PENDING") {
      return res.status(400).json({
        message: "Only PENDING bookings can be canceled by the customer",
      });
    }

    // 🔹 نتحقق من أي Payment مربوط بالحجز
    const payment = await Payment.findOne({ booking: booking._id });

    if (payment && payment.status === "AUTHORIZED") {
      // 💳 إلغاء الـ Authorization في Stripe
      await stripe.paymentIntents.cancel(payment.txnId);

      payment.status = "CANCELED_BY_CUSTOMER";
      payment.timeline = payment.timeline || [];
      payment.timeline.push({
        action: "CANCELED_BY_CUSTOMER_BEFORE_CONFIRM",
        by: "CUSTOMER",
        at: new Date(),
      });
      await payment.save();

      // نحدّث نسخة الدفع داخل الحجز نفسه
      booking.payment.status = "REFUNDED"; // أو "PENDING" حسب ما تحبي تسمّيها
    }

    booking.status = "CANCELED";
    booking.timeline = booking.timeline || [];
    booking.timeline.push({
      by: "CUSTOMER",
      action: "CANCELED",
      at: new Date(),
      meta: { reason: "CANCELLED_BEFORE_ACCEPT" },
    });

    await booking.save();

    return res.json({
      success: true,
      message: "Booking canceled successfully",
      booking,
    });
  } catch (err) {
    console.error("cancelCustomerBooking error", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
}