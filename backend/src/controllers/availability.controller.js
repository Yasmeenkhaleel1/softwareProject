// ==============================
//  availability.controller.js
//  النسخة النهائية المطابقة للسيلندر
// ==============================

import mongoose from "mongoose";
import Availability from "../models/availability.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import Booking from "../models/booking.model.js";

// ==========================================
// 🔧 Helper Functions
// ==========================================

// تحويل أي وقت Local إلى UTC ثابت
function toUTC(d) {
  return new Date(Date.UTC(
    d.getFullYear(),
    d.getMonth(),
    d.getDate(),
    d.getHours(),
    d.getMinutes(),
    d.getSeconds()
  ));
}

function addMin(d, m) {
  return new Date(d.getTime() + m * 60000);
}

function overlaps(aS, aE, bS, bE) {
  return aS < bE && bS < aE;
}

// ==========================================
// 1️⃣ GET My Availability (Expert)
// ==========================================
export async function getMyAvailability(req, res) {
  try {
    const userId = req.user.id;

    const profile = await ExpertProfile.findOne({
      userId,
      status: "approved",
    }).select("_id");

    if (!profile)
      return res.status(404).json({ message: "Approved profile not found" });

    const av = await Availability.findOne({
      expert: profile._id,
      status: { $in: ["ACTIVE", "DRAFT"] },
    });

    if (!av) {
      return res.json({ availability: null });
    }

    return res.json({ availability: av });
  } catch (err) {
    console.error("getMyAvailability error", err);
    return res.status(500).json({ message: err.message });
  }
}

// ==========================================
// 2️⃣ Update Availability (Expert)
// ==========================================
export async function updateMyAvailability(req, res) {
  try {
    const userId = req.user.id;
    const { rules = [], exceptions = [], bufferMinutes = 15 } = req.body;

    const profile = await ExpertProfile.findOne({
      userId,
      status: "approved",
    }).select("_id");

    if (!profile)
      return res.status(404).json({ message: "Approved profile not found" });

    // حجوزات قادمة (لمنع التعارض)
    const nowUTC = new Date();
    const upcoming = await Booking.find({
      expert: profile._id,
      status: { $in: ["CONFIRMED", "IN_PROGRESS", "PENDING"] },
      startAt: { $gte: nowUTC },
    }).lean();

    // قائمة أيام الدوام الفعلية
    const enabledDays = rules.map(r => r.dow);
    const allDays = [0, 1, 2, 3, 4, 5, 6];
    const disabledDays = allDays.filter(d => !enabledDays.includes(d));

    let conflict = false;

    for (const b of upcoming) {
      const day = b.startAt.getUTCDay();
      if (disabledDays.includes(day)) {
        conflict = true;
        break;
      }
    }

    const av = await Availability.findOneAndUpdate(
      { expert: profile._id },
      {
        expert: profile._id,
        userId,
        rules,
        exceptions,
        bufferMinutes,
        status: "ACTIVE",
      },
      { new: true, upsert: true }
    );

    let msg = "Availability updated successfully.";
    if (conflict) {
      msg +=
        " ⚠️ Warning: You have bookings on days you disabled. System will not allow new bookings on these days.";
    }

    return res.json({
      success: true,
      message: msg,
      availability: av,
    });

  } catch (err) {
    console.error("updateMyAvailability error", err);
    return res.status(500).json({ message: err.message });
  }
}

// ==========================================
// 3️⃣ Get Available Slots (Public)
//     — مطابق للسيلندر 100%
// ==========================================
export async function getAvailableSlots(req, res) {
  try {
    const expertId = req.params.expertProfileId;

    if (!mongoose.Types.ObjectId.isValid(expertId)) {
      return res.status(400).json({ message: "Invalid expertProfileId" });
    }

    const { from, to, durationMinutes = 60 } = req.query;

    if (!from || !to) {
      return res.status(400).json({
        message: "from and to params are required (YYYY-MM-DD)",
      });
    }

    // from/to Local → then convert to UTC
    const fromLocal = new Date(`${from}T00:00:00`);
    const toLocalExclusive = new Date(`${to}T00:00:00`);

    const fromUTC = toUTC(fromLocal);
    const toUTCExclusive = toUTC(toLocalExclusive);

    // availability
    const av = await Availability.findOne({
      expert: expertId,
      status: "ACTIVE",
    }).lean();

    if (!av) return res.json({ slots: [] });

    // profiles of that user (approved/archived)
    const prof = await ExpertProfile.findById(expertId)
      .select("userId")
      .lean();

    const profiles = await ExpertProfile.find({
      userId: prof.userId,
    })
      .select("_id")
      .lean();

    const expertIds = profiles.map(p => p._id);

    // bookings (UTC-based)
    const blockingStatuses = ["CONFIRMED", "IN_PROGRESS"];
    const bookings = await Booking.find({
      expert: { $in: expertIds },
      status: { $in: blockingStatuses },
      startAt: { $gte: fromUTC, $lt: toUTCExclusive },
    })
      .select("startAt endAt")
      .lean();

    const results = [];

    for (let day = new Date(fromLocal); day < toLocalExclusive; day = addMin(day, 1440)) {
      const dow = day.getDay();
      const rules = av.rules.filter(r => r.dow === dow);

      for (const rule of rules) {
        const [sh, sm] = rule.start.split(":").map(Number);
        const [eh, em] = rule.end.split(":").map(Number);

        const startLocal = new Date(day.getFullYear(), day.getMonth(), day.getDate(), sh, sm);
        const endLocal = new Date(day.getFullYear(), day.getMonth(), day.getDate(), eh, em);

        let cursorLocal = new Date(startLocal);

        while (addMin(cursorLocal, durationMinutes) <= endLocal) {
          const sLocal = new Date(cursorLocal);
          const eLocal = addMin(cursorLocal, durationMinutes);

          const sUTC = toUTC(sLocal);
          const eUTC = toUTC(eLocal);

          cursorLocal = addMin(eLocal, av.bufferMinutes || 0);

          const isOverlap = bookings.some(b =>
            overlaps(sUTC, eUTC, b.startAt, b.endAt)
          );

          if (!isOverlap) {
            results.push({
              startAt: sUTC.toISOString(),
              endAt: eUTC.toISOString(),
            });
          }
        }
      }
    }

    results.sort((a, b) => new Date(a.startAt) - new Date(b.startAt));

    return res.json({ slots: results });
  } catch (err) {
    console.error("getAvailableSlots error", err);
    return res.status(500).json({ message: err.message });
  }
}

