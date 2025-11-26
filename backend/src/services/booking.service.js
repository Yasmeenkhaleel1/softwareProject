// src/services/booking.service.js
import mongoose from "mongoose";
import Booking from "../models/booking.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import { isBeforeHours } from "../utils/time.js";

/**
 * ✅ يمنع التضارب في المواعيد لأي بروفايل تابع لنفس المستخدم (expertUserId)
 */


export async function assertNoOverlap({ expertId, startAt, endAt, excludeId }) {
  // expertId ممكن يكون:
  // - ExpertProfile._id (أكثر إشي منطقي)
  // - أو userId مباشرة في بعض الاستخدامات
  let expertUserId;

  // 1️⃣ جرّب نعتبره ExpertProfile
  const profile = await ExpertProfile.findById(expertId)
    .select("userId")
    .lean();

  if (profile) {
    expertUserId = profile.userId;
  } else {
    // 2️⃣ لو مش بروفايل، نعتبره userId (لدعم بعض الاستدعاءات القديمة)
    expertUserId = expertId;
  }

  const userObjectId = new mongoose.Types.ObjectId(expertUserId);

  // 3️⃣ كل البروفايلات التابعة لهذا اليوزر
  const profiles = await ExpertProfile.find({ userId: userObjectId })
    .select("_id")
    .lean();

  const expertProfileIds = profiles.map((p) => p._id);

  // 4️⃣ استعلام موحد:
  // - أي حجز تابع لنفس الـ expertUserId (نظام جديد)
  // - أو لأي بروفايل من بروفايلاته (نظام قديم)
  // - وحالته CONFIRMED / IN_PROGRESS
  // - ومتقاطع زمنياً مع [startAt, endAt]
  const overlap = await Booking.findOne({
    _id: { $ne: excludeId },
    status: { $in: ["CONFIRMED", "IN_PROGRESS"] },
    $or: [
      { expertUserId: userObjectId },
      { expert: { $in: expertProfileIds } },
    ],
    startAt: { $lt: endAt },
    endAt: { $gt: startAt },
  }).lean();

  if (overlap) {
    throw new Error(
      "Time overlaps with another confirmed booking for this expert."
    );
  }
}

/**
 * ✅ التحقق من إمكانية إعادة الجدولة
 */
export async function canReschedule(booking) {
  const now = new Date();
  const allowed = isBeforeHours(
    now,
    booking.startAt,
    booking.policy?.rescheduleBeforeHours ?? 24
  );
  if (!allowed) throw new Error("Reschedule window has passed");
}

/**
 * ✅ التحقق من إمكانية الإلغاء
 */
export async function canCancel(booking) {
  const now = new Date();
  const allowed = isBeforeHours(
    now,
    booking.startAt,
    booking.policy?.cancelBeforeHours ?? 24
  );
  if (!allowed) throw new Error("Cancel window has passed");
}

/**
 * ✅ إحصائيات الخبير لجميع بروفايلاته
 */
export async function statsForExpert(expertId, { from, to }) {
  let expertUserId;
  const profile = await ExpertProfile.findById(expertId)
    .select("userId")
    .lean();

  if (profile) {
    expertUserId = profile.userId;
  } else {
    expertUserId = expertId;
  }

  const userObjectId = new mongoose.Types.ObjectId(expertUserId);

  const profiles = await ExpertProfile.find({ userId: userObjectId })
    .select("_id")
    .lean();
  const expertProfileIds = profiles.map((p) => p._id);

  const match = {
    $or: [
      { expertUserId: userObjectId },
      { expert: { $in: expertProfileIds } },
    ],
  };

  if (from || to) match.startAt = {};
  if (from) match.startAt.$gte = new Date(from);
  if (to) match.startAt.$lte = new Date(to);

  const [agg] = await Booking.aggregate([
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

  return agg || [];
}

