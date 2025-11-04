// src/controllers/expertBooking.controller.js
import Booking from "../models/booking.model.js";
import Service from "../models/expert/service.model.js";
import { nextBookingCode } from "../utils/codes.js";
import mongoose from "mongoose";
import { assertNoOverlap, canReschedule, canCancel } from "../services/booking.service.js";

import ExpertProfile from "../models/expert/expertProfile.model.js";

async function getExpertProfileId(userId) {
  const p = await ExpertProfile.findOne({
    userId: new mongoose.Types.ObjectId(userId)   // ← إجبار التحويل
    // أو استخدم { user: new ObjectId(userId) } إذا كان الحقل في السكيمة اسمه "user"
  }).lean();

  if (!p) {
    const err = new Error("Expert profile not found");
    err.status = 404;
    throw err;
  }
  return p._id;
}

function ensureOwnership(booking, expertId) {
if (!booking || String(booking.expert) !== String(expertId)) {
const err = new Error("Booking not found");
err.status = 404;
throw err;
}
}
export const listBookings = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const { status, from, to, q, page = 1, limit = 10 } = req.query;
const where = { expert: expertId };
if (status) where.status = status;
if (from || to) where.startAt = {};
if (from) where.startAt.$gte = new Date(from);
if (to) where.startAt.$lte = new Date(to);
 // بحث بسيط بالعميل أو الكود 
const query = Booking.find(where)
.populate("customer", "name email")
.populate("service", "title durationMinutes")
.sort({ startAt: 1 })
.skip((+page - 1) * +limit)
.limit(+limit);
// إذا بدون lookup$ أو اسم العميل (تحتاج code يمكن استخدامه لتصفية إضافية على "q ":مالحظة populate)
const data = await query.lean();
const total = await Booking.countDocuments(where);
res.json({ data, total, page: +page, pages: Math.ceil(total / +limit) });
};
export const getBooking = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const booking = await Booking.findById(req.params.id)
.populate("customer", "name email")
.populate("service").lean();
ensureOwnership(booking, expertId);
res.json({ booking });
};
export const createBooking = async (req, res) => {
//ُ مخصص عادة للعميل، لكن نبقيه هنا لأغراض الاختبار الداخلي 
const expertId = await getExpertProfileId(req.user.id);
const { customerId, serviceId, startAtIso, timezone } = req.body;
const service = await Service.findById(serviceId).lean();
if (!service) return res.status(400).json({ error: "Service not found" });
const startAt = new Date(startAtIso);
const endAt = new Date(startAt.getTime() + (service.durationMinutes || 60) *
60000);
await assertNoOverlap({ expertId, startAt, endAt });
const doc = await Booking.create({
code: nextBookingCode(),
expert: expertId,
customer: customerId,
service: serviceId,
serviceSnapshot: {
title: service.title,
durationMinutes: service.durationMinutes,
price: service.price,
currency: service.currency || "USD",
},
startAt,
endAt,
timezone: timezone || "Asia/Hebron",
status: "PENDING",
payment: {
status: "PENDING",
amount: service.price,
currency: service.currency || "USD",
},
timeline: [{ by: "SYSTEM", action: "CREATED" }],
});
res.status(201).json({ booking: doc });
};
export const acceptBooking = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
if (booking.status !== "PENDING") return res.status(400).json({ error: "Only PENDING can be accepted" });
await assertNoOverlap({ expertId, startAt: booking.startAt, endAt:
booking.endAt, excludeId: booking._id });
booking.status = "CONFIRMED";
booking.timeline.push({ by: "EXPERT", action: "CONFIRMED" });
await booking.save();
res.json({ booking });
};

export const declineBooking = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
if (booking.status !== "PENDING") return res.status(400).json({ error: "Only PENDING can be declined" });
booking.status = "CANCELED";
booking.timeline.push({ by: "EXPERT", action: "DECLINED" });
await booking.save();
res.json({ booking });
};
export const rescheduleBooking = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const { startAtIso } = req.body;
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
await canReschedule(booking);
const newStart = new Date(startAtIso);
const newEnd = new Date(newStart.getTime() +
(booking.serviceSnapshot?.durationMinutes || 60) * 60000);
await assertNoOverlap({ expertId, startAt: newStart, endAt: newEnd,
excludeId: booking._id });
booking.startAt = newStart;
booking.endAt = newEnd;
booking.timeline.push({ by: "EXPERT", action: "RESCHEDULED", meta: { to:
newStart } });
await booking.save();
res.json({ booking });
};
export const startBooking = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
if (booking.status !== "CONFIRMED") return res.status(400).json({ error:
"Only CONFIRMED can start" });
booking.status = "IN_PROGRESS";
booking.timeline.push({ by: "EXPERT", action: "STARTED" });
await booking.save();
res.json({ booking });
};
export const completeBooking = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
if (booking.status !== "IN_PROGRESS") return res.status(400).json({ error:
"Only IN_PROGRESS can complete" });
booking.status = "COMPLETED";
booking.payment.status = booking.payment.status === "AUTHORIZED" ?
"CAPTURED" : booking.payment.status;
booking.timeline.push({ by: "EXPERT", action: "COMPLETED" });
await booking.save();
res.json({ booking });
};
export const cancelBooking = async (req, res) => {
  const expertId = await getExpertProfileId(req.user.id);
const { reason } = req.body || {};
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
await canCancel(booking);
if (["COMPLETED", "CANCELED", "NO_SHOW"].includes(booking.status)) {
return res.status(400).json({ error: "Cannot cancel at this stage" });
}
booking.status = "CANCELED";
booking.timeline.push({ by: "EXPERT", action: "CANCELED", meta: { reason } });
await booking.save();
res.json({ booking });
};
export const markNoShow = async (req, res) => {
const expertId = await getExpertProfileId(req.user.id);
const booking = await Booking.findById(req.params.id);
ensureOwnership(booking, expertId);
if (!["CONFIRMED", "IN_PROGRESS"].includes(booking.status)) return
res.status(400).json({ error: "Invalid state" });
booking.status = "NO_SHOW";
booking.timeline.push({ by: "EXPERT", action: "NO_SHOW" });
await booking.save();
res.json({ booking });
};
export const overviewStats = async (req, res) => {
  //تبسيط: إحصائيات حسب الحالة + إجمالي المدفوع 
const expertId = await getExpertProfileId(req.user.id);
const { from, to } = req.query;
const match = { expert: expertId };
if (from || to) match.startAt = {};
if (from) match.startAt.$gte = new Date(from);
if (to) match.startAt.$lte = new Date(to);
const data = await Booking.aggregate([
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
res.json({ data });
};

