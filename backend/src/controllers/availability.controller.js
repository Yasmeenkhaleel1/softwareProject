// src/controllers/availability.controller.js
import Availability from "../models/availability.model.js";
import Booking from "../models/booking.model.js";
import mongoose from "mongoose";

const toMinutes = (hhmm) => {
  const [h, m] = hhmm.split(":").map(Number);
  return (h * 60) + (m || 0);
};

const pad2 = (n) => (n < 10 ? `0${n}` : `${n}`);
const dateToYMD = (d) =>
  `${d.getUTCFullYear()}-${pad2(d.getUTCMonth() + 1)}-${pad2(
    d.getUTCDate()
  )}`;

const addMin = (d, m) => new Date(d.getTime() + m * 60000);

const rangesOverlap = (aStart, aEnd, bStart, bEnd) =>
  aStart < bEnd && bStart < aEnd;

const BLOCKING_STATUSES = new Set(["PENDING", "CONFIRMED", "IN_PROGRESS"]);

/**
 * build windows for a day – يدعم rules.windows و rules.start/end
 */
function buildWindowsForDay(av, dayUtc) {
  const dow = dayUtc.getUTCDay();
  let windows = [];

  for (const r of (av.rules || [])) {
    if (r.dow !== dow) continue;

    if (Array.isArray(r.windows) && r.windows.length) {
      for (const w of r.windows) {
        if (w.start && w.end) windows.push({ start: w.start, end: w.end });
      }
    } else if (r.start && r.end) {
      windows.push({ start: r.start, end: r.end });
    }
  }

  const dYMD = dateToYMD(dayUtc);
  const exception = (av.exceptions || []).find((e) => e.date === dYMD);
  if (exception) {
    if (exception.off) {
      windows = [];
    } else if (Array.isArray(exception.windows) && exception.windows.length) {
      windows = exception.windows
        .filter((w) => w.start && w.end)
        .map((w) => ({ start: w.start, end: w.end }));
    }
  }

  return windows.map((w) => {
    const startMin = toMinutes(w.start);
    const endMin = toMinutes(w.end);
    const start = new Date(
      Date.UTC(
        dayUtc.getUTCFullYear(),
        dayUtc.getUTCMonth(),
        dayUtc.getUTCDate(),
        0,
        0,
        0
      )
    );
    const end = new Date(start);
    start.setUTCMinutes(startMin);
    end.setUTCMinutes(endMin);
    return { start, end };
  });
}

async function getBlockingBookings(expertId, dayStartUtc, dayEndUtc) {
  return Booking.find({
    expert: expertId,
    status: { $in: Array.from(BLOCKING_STATUSES) },
    $or: [
      { startAt: { $lt: dayEndUtc }, endAt: { $gt: dayStartUtc } },
      { startAt: { $gte: dayStartUtc, $lt: dayEndUtc } },
      { endAt: { $gt: dayStartUtc, $lte: dayEndUtc } },
    ],
  }).select("startAt endAt status");
}

function sliceWindowIntoSlots(windowStart, windowEnd, durationMin, bufferMin) {
  const slots = [];
  let cursor = new Date(windowStart);
  while (addMin(cursor, durationMin) <= windowEnd) {
    const s = new Date(cursor);
    const e = addMin(cursor, durationMin);
    cursor = addMin(e, bufferMin); // buffer بعد كل slot
    slots.push({ start: s, end: e });
  }
  return slots;
}

function filterSlots(slots, bookings) {
  return slots.filter((slot) => {
    return !bookings.some((b) =>
      rangesOverlap(slot.start, slot.end, b.startAt, b.endAt)
    );
  });
}

/**
 * ✅ THIS IS THE IMPORTANT EXPORT
 * GET /api/experts/:expertId/availability/slots
 */
export async function getAvailableSlots(req, res) {
  try {
    const { expertId } = req.params;

    // لو expert عندك ObjectId في الـ DB هذا مفيد، لو لا تقدري تشيليه
    if (!mongoose.Types.ObjectId.isValid(expertId)) {
      return res.status(400).json({ message: "Invalid expertId" });
    }

    const from = req.query.from;
    const to = req.query.to;
    const durationMinutes = parseInt(req.query.durationMinutes || "60", 10);

    if (!from || !to) {
      return res
        .status(400)
        .json({ message: "from and to are required (YYYY-MM-DD)" });
    }

    const fromUtc = new Date(`${from}T00:00:00.000Z`);
    const toUtcExclusive = new Date(`${to}T00:00:00.000Z`);
    if (isNaN(fromUtc) || isNaN(toUtcExclusive) || fromUtc >= toUtcExclusive) {
      return res.status(400).json({ message: "Invalid date range" });
    }

    const av = await Availability.findOne({ expert: expertId });
    if (!av) return res.json({ slots: [] });

    const bufferMin = av.bufferMinutes || 0;
    const results = [];

    for (
      let d = new Date(fromUtc);
      d < toUtcExclusive;
      d = addMin(d, 24 * 60)
    ) {
      const dayStart = new Date(
        Date.UTC(
          d.getUTCFullYear(),
          d.getUTCMonth(),
          d.getUTCDate(),
          0,
          0,
          0
        )
      );
      const dayEnd = addMin(dayStart, 24 * 60);

      const windows = buildWindowsForDay(av, dayStart);
      if (!windows.length) continue;

      const dayBookings = await getBlockingBookings(
        expertId,
        dayStart,
        dayEnd
      );

      for (const w of windows) {
        const sliced = sliceWindowIntoSlots(
          w.start,
          w.end,
          durationMinutes,
          bufferMin
        );
        const free = filterSlots(sliced, dayBookings);

        for (const s of free) {
          results.push({
            startAt: s.start.toISOString(),
            endAt: s.end.toISOString(),
            label: `${dateToYMD(s.start)} ${pad2(
              s.start.getUTCHours()
            )}:${pad2(s.start.getUTCMinutes())}–${pad2(
              s.end.getUTCHours()
            )}:${pad2(s.end.getUTCMinutes())} UTC`,
          });
        }
      }
    }

    results.sort((a, b) => (a.startAt < b.startAt ? -1 : 1));
    return res.json({ slots: results });
  } catch (err) {
    console.error("getAvailableSlots error", err);
    return res
      .status(500)
      .json({ message: "Server error", error: err.message });
  }
}
