// routes/admin.route.js
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";
import mongoose from "mongoose";
import nodemailer from "nodemailer";
import dotenv from "dotenv";

import User from "../models/user/user.model.js";
import Notification from "../models/notification.model.js";
import ExpertProfile from "../models/expert/expertProfile.model.js";
import Booking from "../models/booking.model.js";
import Service from "../models/expert/service.model.js";
import Availability from "../models/availability.model.js";

dotenv.config();
const router = Router();

/* =========================
   ✉️ إعداد البريد الإلكتروني
   ========================= */
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT),
  secure: process.env.SMTP_SECURE === "true",
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

async function sendExpertStatusEmail(user, approved, reason = "") {
  const subject = approved
    ? "Your Expert Profile has been Approved ✅"
    : "Your Expert Profile has been Rejected ❌";

  const html = `
    <div style="font-family: Arial; line-height:1.6; color:#333;">
      <h2>${approved ? "🎉 Congratulations!" : "⚠️ Update on your Application"}</h2>
      <p>Dear <b>${user.name || "Expert"}</b>,</p>
      <p>
        ${
          approved
            ? "We are happy to inform you that your expert profile has been <b>approved</b> by the admin. You can now access all expert features on the Lost Treasures platform."
            : "Unfortunately, your expert profile has been <b>rejected</b> by the admin."
        }
      </p>
      ${!approved && reason ? `<p><b>Reason:</b> ${reason}</p>` : ""}
      <p style="margin-top:20px;">Best regards,<br/>Lost Treasures Team</p>
    </div>
  `;

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to: user.email,
    subject,
    html,
  });
}

/* =========================
   📊 إحصائيات لوحة التحكم (Dashboard)
   ========================= */

//const Payment = mongoose.model("payments", new mongoose.Schema({}, { strict: false }));


router.get("/stats", auth(), requireRole("ADMIN"), async (req, res) => {
  try {
    const [totalUsers, totalExperts, totalCustomers] = await Promise.all([
      User.countDocuments({}),
      User.countDocuments({ role: "EXPERT" }),
      User.countDocuments({ role: "CUSTOMER" }),
    ]);

    const [totalServices, totalBookings] = await Promise.all([
      Service.countDocuments({}),
      Booking.countDocuments({}),
    ]);

    const revenueAgg = await Payment.aggregate([
      { $match: { status: { $in: ["PAID", "SUCCESS", "COMPLETED"] } } },
      { $group: { _id: null, total: { $sum: "$amount" } } },
    ]);

    const totalRevenue = revenueAgg[0]?.total || 0;

    res.json({
      cards: {
        totalUsers,
        totalExperts,
        totalCustomers,
        totalServices,
        totalBookings,
        totalRevenue,
      },
    });
  } catch (e) {
    res.status(500).json({ message: "Failed to load stats", error: e.message });
  }
});

/* =========================
   👀 عرض الخبراء بانتظار الموافقة
   ========================= */
router.get("/experts/pending", auth(), requireRole("ADMIN"), async (req, res) => {
  try {
    // ✅ الآن نبحث في expertprofiles بدل users
    const pendingProfiles = await ExpertProfile.find({ status: "pending" })
      .populate("userId", "name email gender role isVerified isApproved")
      .select("userId name specialization profileImageUrl createdAt updatedAt");

    res.json({ pending: pendingProfiles });
  } catch (e) {
    console.error("❌ Failed to load pending experts:", e.message);
    res.status(500).json({ message: "Failed to load pending experts", error: e.message });
  }
});

/* =========================
   ✅ الموافقة على بروفايل خبير
   ========================= */
router.patch("/experts/:profileId/approve", auth(), requireRole("ADMIN"), async (req, res) => {
  try {
    const { profileId } = req.params;

    // 🔹 الخطوة 1: إيجاد البروفايل الحالي pending
    const profile = await ExpertProfile.findById(profileId);
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    // 🔹 الخطوة 2: إيجاد المستخدم المرتبط
    const user = await User.findById(profile.userId).select("_id name email isApproved");
    if (!user) return res.status(404).json({ message: "User not found" });

    // 🔹 الخطوة 3: أرشفة أي بروفايلات approved سابقة لنفس المستخدم
    await ExpertProfile.updateMany(
  {
    userId: user._id,
    _id: { $ne: profile._id },           // استثناء البروفايل الحالي
    status: { $in: ["approved", "pending"] },
  },
  { $set: { status: "archived" } }
);

// ثم فعّل الحالي
// ثم فعّل الحالي
profile.status = "approved";
await profile.save();

// 🔹 نسخ Availability القديمة (إن وجدت)


const oldAv = await Availability.findOne({
  userId: user._id,
  status: "ACTIVE",
}).lean();

if (oldAv) {
  await Availability.create({
    expert: profile._id,
    userId: user._id,
    bufferMinutes: oldAv.bufferMinutes,
    rules: oldAv.rules,
    exceptions: oldAv.exceptions,
    status: "DRAFT",
    versionOf: oldAv._id,
  });
}


    // 🔹 الخطوة 5: تحديث المستخدم نفسه
    user.isApproved = true;
    await user.save();

    // 🔹 الخطوة 6: إرسال البريد والإشعار
    await sendExpertStatusEmail(user, true);
    await Notification.create({
      userId: user._id,
      title: "Profile Approved ✅",
      message:
        "Congratulations! Your updated expert profile has been approved by the admin.",
      type: "success",
    });

    res.json({ message: "Expert profile approved successfully.", user, profile });
  } catch (e) {
    console.error("❌ Approval error:", e.message);
    res.status(500).json({ message: "Approval failed", error: e.message });
  }
});

/* =========================
   ❌ رفض بروفايل خبير
   ========================= */
router.patch("/experts/:profileId/reject", auth(), requireRole("ADMIN"), async (req, res) => {
  try {
    const { profileId } = req.params;
    const { reason } = req.body;

    const profile = await ExpertProfile.findById(profileId);
    if (!profile) return res.status(404).json({ message: "Profile not found" });

    const user = await User.findById(profile.userId).select("_id name email isApproved");
    if (!user) return res.status(404).json({ message: "User not found" });

    // ❌ رفض هذا البروفايل فقط
    profile.status = "rejected";
    profile.rejectionReason = reason || "No reason provided.";
    await profile.save();

    // ✅ هل لا يزال لديه بروفايل approved قديم؟
    const stillApproved = await ExpertProfile.findOne({
      userId: user._id,
      status: "approved",
    });

    // 🔒 لو مافي ولا approved → ساعتها نوقفه
    if (!stillApproved) {
      user.isApproved = false;
      await user.save();
    }

    // (اختياري) تقدر ترسل إيميل / Notification هنا

    res.json({ message: "Expert profile rejected.", user, profile });
  } catch (e) {
    console.error("❌ Reject error:", e.message);
    res.status(500).json({ message: "Reject failed", error: e.message });
  }
});


/* =========================
   👤 عرض بروفايل خبير معيّن (للأدمن)
   ========================= */
// ✅ إحضار بيانات البروفايل مع بيانات المستخدم (populate)
router.get("/experts/:id/profile", async (req, res) => {
  try {
    const profile = await ExpertProfile.findById(req.params.id)
      .populate("userId", "name email gender age isVerified isApproved"); // 👈 هنا السحر

    if (!profile)
      return res.status(404).json({ message: "Expert profile not found" });

    res.status(200).json({
      user: profile.userId, // ← هنا سيرجع object كامل (وليس مجرد ID)
      profile,              // ← البروفايل نفسه
    });
  } catch (err) {
    console.error("❌ Error fetching expert profile:", err);
    res.status(500).json({ message: "Server error fetching profile" });
  }
});


export default router;
