//availability.service
import mongoose from "mongoose";
import Booking from "../models/booking.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";

const BLOCKING_STATUSES = ["CONFIRMED", "IN_PROGRESS"];

/**
 * ✅ يتحقق إن كانت الـ availability قابلة للتعديل أم لا
 * - يمنع التعديل على الأيام اللي فيها حجوزات مؤكدة
 * - يمنع التعديل قبل 24 ساعة من موعد الجلسة
 */
export async function canModifyAvailability(expertProfileId) {
  if (!mongoose.Types.ObjectId.isValid(expertProfileId)) return false;

  const profile = await ExpertProfile.findById(expertProfileId)
    .select("userId")
    .lean();

  if (!profile) return false;

  const profiles = await ExpertProfile.find({ userId: profile.userId })
    .select("_id")
    .lean();

  const expertProfileIds = profiles.map((p) => p._id);
  const now = new Date();

  // نحظر التعديل لو فيه حجوزات مؤكدة أو قريبة
  const conflict = await Booking.findOne({
    expert: { $in: expertProfileIds },
    status: { $in: BLOCKING_STATUSES },
    startAt: { $gte: now },
  }).lean();

  return !conflict; // true = آمن للتعديل
}
