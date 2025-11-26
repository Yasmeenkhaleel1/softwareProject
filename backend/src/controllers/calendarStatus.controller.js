//calendarstatus.controller
import mongoose from "mongoose";
import Availability from "../models/availability.model.js";
import Booking from "../models/booking.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

// 🌍 helper لتحويل أي تاريخ إلى UTC
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

function overlaps(aS, aE, bS, bE) {
  return aS < bE && bS < aE;
}

/**
 * 📅 Calendar-Status (UTC Based)
 */
export async function getCalendarStatus(req, res) {
  try {
    const expertId = req.params.expertId;
    const { from, to, durationMinutes = 60 } = req.query;

    if (!mongoose.Types.ObjectId.isValid(expertId))
      return res.status(400).json({ message: "Invalid expertId" });

    if (!from || !to)
      return res.status(400).json({ message: "from/to required" });

    // 🟢 from/to Local → ثم نحولها UTC
    const fromLocal = new Date(`${from}T00:00:00`);
    const toLocalExclusive = new Date(`${to}T00:00:00`);

    const fromUTC = toUTC(fromLocal);
    const toUTCExclusive = toUTC(toLocalExclusive);

    // 🟢 availability
    const av = await Availability.findOne({
      expert: expertId,
      status: "ACTIVE",
    }).lean();

    if (!av) return res.json({ days: [] });

    // 🟢 جميع بروفايلات الخبير
    const prof = await ExpertProfile.findById(expertId).select("userId").lean();
    if (!prof) return res.status(404).json({ message: "Profile not found" });

    const allProfiles = await ExpertProfile.find({ userId: prof.userId })
      .select("_id")
      .lean();

    const profileIds = allProfiles.map(p => p._id);

    // 🟢 الحجوزات المؤكدة فقط
    const bookings = await Booking.find({
      expert: { $in: profileIds },
      status: { $in: ["CONFIRMED", "IN_PROGRESS"] },
      startAt: { $gte: fromUTC, $lt: toUTCExclusive }
    })
      .select("startAt endAt")
      .lean();

    const days = [];

    const addMin = (d, m) => new Date(d.getTime() + m * 60000);

    // 🟢 بناء الأيام
    for (let day = new Date(fromLocal); day < toLocalExclusive; day = addMin(day, 1440)) {
      const dateStr = `${day.getFullYear()}-${String(
        day.getMonth() + 1
      ).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;

      const dow = day.getDay();

      // عطلة؟
      const exception = (av.exceptions || []).find(e => e.date === dateStr);
      if (exception?.off) {
        days.push({ date: dateStr, status: "OFF", slots: [] });
        continue;
      }

      const rules = (av.rules || []).filter(r => r.dow === dow);
      if (rules.length === 0) {
        days.push({ date: dateStr, status: "OFF", slots: [] });
        continue;
      }

      const slots = [];

      for (const rule of rules) {
        const [sh, sm] = rule.start.split(":").map(Number);
        const [eh, em] = rule.end.split(":").map(Number);

        const startLocal = new Date(day.getFullYear(), day.getMonth(), day.getDate(), sh, sm);
        const endLocal = new Date(day.getFullYear(), day.getMonth(), day.getDate(), eh, em);

        let cursor = new Date(startLocal);

        while (addMin(cursor, durationMinutes) <= endLocal) {
          const sLocal = new Date(cursor);
          const eLocal = addMin(cursor, durationMinutes);

          cursor = addMin(eLocal, av.bufferMinutes || 0);

          // 🟢 تحويل إلى UTC قبل المقارنة
          const sUTC = toUTC(sLocal);
          const eUTC = toUTC(eLocal);

          const isBusy = bookings.some(b => overlaps(sUTC, eUTC, b.startAt, b.endAt));

          // 🟢 نرجع القيم بصيغة UTC ISO
          slots.push({
            startAt: sUTC.toISOString(),
            endAt: eUTC.toISOString(),
            available: !isBusy
          });
        }
      }

      const availableCount = slots.filter(s => s.available).length;

      days.push({
        date: dateStr,
        status: availableCount === 0 ? "FULL" : "AVAILABLE",
        slots
      });
    }

    return res.json({ days });
  } catch (err) {
    console.error("getCalendarStatus error:", err);
    res.status(500).json({ message: "Server error", error: err.message });
  }
}
