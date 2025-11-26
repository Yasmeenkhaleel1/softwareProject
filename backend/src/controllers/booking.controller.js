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

/**
 * 🎯 Public booking creation endpoint (for Customers)
 * POST /api/public/bookings
 */
/**
 * 🎯 Public booking creation endpoint (for Customers)
 * POST /api/public/bookings
 */
export async function createBookingPublic(req, res) {
  try {
    const {
      expertId,      // ExpertProfile._id
      serviceId,     // Service._id
      startAt,
      endAt,
      timezone = "Asia/Hebron",
      customerNote = "",
      customerId,    // required
      paymentId,     // optional
    } = req.body || {};

    // ✅ 1. تحقق المعطيات الأساسية
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

    // ✅ 2. تحقق أن الخبير فعلاً Approved
    const profile = await ExpertProfile.findById(expertId)
      .select("status userId")
      .lean();

    if (!profile || profile.status !== "approved") {
      return res
        .status(404)
        .json({ message: "Expert not found or not approved" });
    }

    const expertUserId = profile.userId;

    // ✅ 3. تحقق أن الخدمة فعلاً تابعة لهذا الخبير
    const svc = await Service.findOne({
      _id: serviceId,
      expert: expertUserId, // Service.expert = User._id
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

    // ✅ 4. تحقق من مدة الجلسة
    const expectedMin = svc.durationMinutes || Math.round((end - start) / 60000);
    const actualMin = Math.round((end - start) / 60000);
    if (actualMin !== expectedMin) {
      return res.status(400).json({
        message: `Invalid slot duration. Expected ${expectedMin} minutes.`,
      });
    }

    // ✅ 5. 🔒 تحقق من أن اليوم والوقت متاحين حسب Availability
    const Availability = (await import("../models/availability.model.js")).default;
    const av = await Availability.findOne({
      expert: expertId,
      status: "ACTIVE",
    }).lean();

    if (!av) {
      return res.status(400).json({
        message: "Expert has not set availability yet.",
      });
    }

    const dayOfWeek = start.getUTCDay(); // 0-6
    const activeDays = (av.rules || []).map((r) => r.dow);
    const dateStr = `${start.getUTCFullYear()}-${(start.getUTCMonth() + 1)
      .toString()
      .padStart(2, "0")}-${start.getUTCDate().toString().padStart(2, "0")}`;

    // ❌ إذا اليوم مش ضمن الأيام المفعلة
    if (!activeDays.includes(dayOfWeek)) {
      return res.status(400).json({
        message: "❌ This day is not available for bookings. Please choose another date.",
      });
    }

    // ⚠️ تحقق من الاستثناءات (Days Off / Custom Windows)
    const exception = (av.exceptions || []).find((e) => e.date === dateStr);
    if (exception) {
      if (exception.off === true) {
        return res.status(400).json({
          message: "⚠️ This date is marked as a day off by the expert.",
        });
      }

      // تحقق من windows إن وُجدت
      if (exception.windows && exception.windows.length > 0) {
        const toMinutes = (t) => {
          const [h, m] = t.split(":").map(Number);
          return h * 60 + m;
        };
        const startMin = start.getUTCHours() * 60 + start.getUTCMinutes();
        const endMin = end.getUTCHours() * 60 + end.getUTCMinutes();

        const withinWindow = exception.windows.some((w) => {
          const ws = toMinutes(w.start);
          const we = toMinutes(w.end);
          return startMin >= ws && endMin <= we;
        });

        if (!withinWindow) {
          return res.status(400).json({
            message:
              "⚠️ This time is outside the expert’s available windows for that day.",
          });
        }
      }
    }

    // ✅ 6. تحقق من عدم وجود تعارض بالحجوزات
    await assertNoOverlap({
      expertId,
      startAt: start,
      endAt: end,
    });

    // ✅ 7. منع التكرار لنفس العميل في نفس الخدمة والوقت
    const duplicate = await Booking.findOne({
      expert: expertId,
      customer: customerId,
      service: serviceId,
      startAt: start,
      status: { $nin: Array.from(NON_BLOCKING) },
    }).lean();

    if (duplicate) {
      return res.status(400).json({
        message: "You already have a booking for this slot.",
      });
    }

    // ✅ 8. ربط الدفع إن وجد
    let paymentDoc = null;
    if (paymentId && mongoose.Types.ObjectId.isValid(paymentId)) {
      paymentDoc = await Payment.findById(paymentId).lean();
    }

    // ✅ 9. إنشاء الحجز
    const booking = await Booking.create({
      code: genCode(),
      expert: expertId,
      expertUserId: expertUserId,
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
            platformFee: 0,
            netToExpert: 0,
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

    // ✅ 10. رجوع النتيجة
    return res.status(201).json({
      message: "✅ Booking created successfully.",
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
        select: "name specialization location status",
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
