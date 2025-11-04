// src/services/booking.service.js
import mongoose from "mongoose";
import Booking from "../models/booking.model.js";
import { isBeforeHours } from "../utils/time.js";
export async function assertNoOverlap({ expertId, startAt, endAt, excludeId }) {
const overlap = await Booking.findOne({
_id: { $ne: excludeId },
expert: new mongoose.Types.ObjectId(expertId),
status: { $in: ["CONFIRMED", "IN_PROGRESS"] },
$or: [
{ startAt: { $lt: endAt }, endAt: { $gt: startAt } }, // زمني تقاطع أي
],
}).lean();
if (overlap) throw new Error("Time overlaps with another confirmed booking");
}
export async function canReschedule(booking) {
const now = new Date();
const allowed = isBeforeHours(now, booking.startAt,
booking.policy?.rescheduleBeforeHours ?? 24);
if (!allowed) throw new Error("Reschedule window has passed");
}
export async function canCancel(booking) {
const now = new Date();
const allowed = isBeforeHours(now, booking.startAt,
booking.policy?.cancelBeforeHours ?? 24);
if (!allowed) throw new Error("Cancel window has passed");
}
export async function statsForExpert(expertId, { from, to }) {
const match = { expert: new mongoose.Types.ObjectId(expertId) };
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
$cond: [{ $eq: ["$payment.status", "CAPTURED"] },
"$payment.amount", 0],
},
},
},
},
]);
return agg || [];
}
