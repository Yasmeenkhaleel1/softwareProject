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
import Payment from "../models/payment.model.js"; // ✅ جديد



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
   🧮 Helper: فلتر التاريخ من query ?from&to
   ========================= */
function buildDateFilter(req) {
  const { from, to } = req.query || {};
  const createdAt = {};
  if (from) createdAt.$gte = new Date(from);
  if (to) createdAt.$lte = new Date(to);
  return Object.keys(createdAt).length ? { createdAt } : {};
}


/* =========================
   📊 إحصائيات لوحة التحكم (Dashboard)
   ========================= */

router.get("/stats", auth(), requireRole("ADMIN"), async (req, res) => {
  try {
    // === Cards ===
    const [totalUsers, totalExperts, totalBookings, totalServices] =
      await Promise.all([
        User.countDocuments({}),
        User.countDocuments({ role: "EXPERT" }),
        Booking.countDocuments({}),
        Service.countDocuments({}),
      ]);

    const payments = await Payment.find({
      status: { $in: ["CAPTURED", "REFUNDED"] },
    }).lean();

    let totalRevenue = 0;
    let totalPlatformFees = 0;
    let totalNetToExperts = 0;
    let totalRefunds = 0;

    for (const p of payments) {
      totalRevenue += p.amount ?? 0;
      totalPlatformFees += p.platformFee ?? 0;
      totalNetToExperts += p.netToExpert ?? 0;
      totalRefunds += p.refundedAmount ?? 0;
    }

    // === Bookings Per Month ===
    const bookingsByMonth = await Booking.aggregate([
      {
        $group: {
          _id: {
            month: { $month: "$createdAt" },
            year: { $year: "$createdAt" },
          },
          count: { $sum: 1 },
        },
      },
      { $sort: { "_id.year": 1, "_id.month": 1 } },
      {
        $project: {
          _id: 0,
          month: "$_id.month",
          year: "$_id.year",
          count: 1,
        },
      },
    ]);

    // === Revenue Per Month ===
    const revenueByMonth = await Payment.aggregate([
      {
        $group: {
          _id: {
            month: { $month: "$createdAt" },
            year: { $year: "$createdAt" },
          },
          revenue: { $sum: "$amount" },
          netToExpert: { $sum: "$netToExpert" },
        },
      },
      { $sort: { "_id.year": 1, "_id.month": 1 } },
      {
        $project: {
          _id: 0,
          month: "$_id.month",
          year: "$_id.year",
          revenue: 1,
          netToExpert: 1,
        },
      },
    ]);

    // === Payment Status Distribution ===
    const paymentsByStatus = await Payment.aggregate([
      {
        $group: {
          _id: "$status",
          count: { $sum: 1 },
        },
      },
      {
        $project: {
          _id: 0,
          status: "$_id",
          count: 1,
        },
      },
    ]);

    res.json({
      cards: {
        totalUsers,
        totalExperts,
        totalBookings,
        totalServices,
        totalRevenue,
        expertEarnings: totalNetToExperts,
        platformEarnings: totalPlatformFees,
        refundsTotal: totalRefunds,
      },
      charts: {
        bookingsByMonth,
        revenueByMonth,
        paymentsByStatus,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error", error: err.message });
  }
});



/* =========================
   💰 Admin Earnings & Refunds Dashboard
   ========================= */

// GET /api/admin/earnings/summary
router.get(
  "/earnings/summary",
  auth(),
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const dateFilter = buildDateFilter(req);
      const { expertId, status } = req.query || {};

      const match = {
        ...dateFilter,
      };

      if (expertId) {
        match.expert = new mongoose.Types.ObjectId(expertId);
      }

      if (status && status !== "ALL") {
        match.status = status;
      }

      const payments = await Payment.find(match).lean();

      let totalProcessed = 0;
      let totalNetToExperts = 0;
      let totalPlatformFees = 0;
      let totalRefunds = 0;

      const statusCounts = {};

      for (const p of payments) {
        totalProcessed += p.amount || 0;
        totalNetToExperts += p.netToExpert || 0;
        totalPlatformFees += p.platformFee || 0;
        totalRefunds += p.refundedAmount || 0;

        const st = p.status || "UNKNOWN";
        statusCounts[st] = (statusCounts[st] || 0) + 1;
      }

      res.json({
        totalProcessed,
        totalNetToExperts,
        totalPlatformFees,
        totalRefunds,
        paymentsCount: payments.length,
        statusCounts,
      });
    } catch (e) {
      console.error("admin earnings summary error:", e);
      res
        .status(500)
        .json({ message: "Failed to load earnings summary", error: e.message });
    }
  }
);

// GET /api/admin/earnings/charts
router.get(
  "/earnings/charts",
  auth(),
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const dateFilter = buildDateFilter(req);
      const { expertId, status } = req.query || {};

      const match = {
        ...dateFilter,
      };
      if (expertId) {
        match.expert = new mongoose.Types.ObjectId(expertId);
      }
      if (status && status !== "ALL") {
        match.status = status;
      }

      // 1) Revenue over time (by day)
      const revenueByDay = await Payment.aggregate([
        { $match: match },
        {
          $group: {
            _id: {
              year: { $year: "$createdAt" },
              month: { $month: "$createdAt" },
              day: { $dayOfMonth: "$createdAt" },
            },
            total: { $sum: "$amount" },
          },
        },
        { $sort: { "_id.year": 1, "_id.month": 1, "_id.day": 1 } },
        {
          $project: {
            _id: 0,
            year: "$_id.year",
            month: "$_id.month",
            day: "$_id.day",
            total: 1,
          },
        },
      ]);

      // 2) Top experts by net earnings
      const topExpertsRaw = await Payment.aggregate([
        { $match: match },
        {
          $group: {
            _id: "$expert",
            net: { $sum: "$netToExpert" },
          },
        },
        { $sort: { net: -1 } },
        { $limit: 8 },
        {
          $lookup: {
            from: "users",
            localField: "_id",
            foreignField: "_id",
            as: "expert",
          },
        },
        {
          $unwind: {
            path: "$expert",
            preserveNullAndEmptyArrays: true,
          },
        },
        {
            $project: {
    expertId: "$_id",
    name: { 
      $ifNull: ["$expert.name", "Unknown"] 
    },
    email: {
      $ifNull: ["$expert.email", "unknown@example.com"]
    },
    net: 1
  }
        },
      ]);

      // 3) Status distribution
      const statusDistribution = await Payment.aggregate([
        { $match: match },
        {
          $group: {
            _id: "$status",
            count: { $sum: 1 },
            total: { $sum: "$amount" },
          },
        },
        {
          $project: {
            _id: 0,
            status: "$_id",
            count: 1,
            total: 1,
          },
        },
      ]);

      res.json({
        revenueByDay,
        topExperts: topExpertsRaw,
        statusDistribution,
      });
    } catch (e) {
      console.error("admin earnings charts error:", e);
      res
        .status(500)
        .json({ message: "Failed to load earnings charts", error: e.message });
    }
  }
);

// GET /api/admin/earnings/payments
router.get(
  "/earnings/payments",
  auth(),
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const dateFilter = buildDateFilter(req);
      const { expertId, status, page = 1, limit = 20 } = req.query || {};

      const pageNum = parseInt(page) || 1;
      const limitNum = Math.min(parseInt(limit) || 20, 100);
      const skip = (pageNum - 1) * limitNum;

      const match = {
        ...dateFilter,
      };

      if (expertId) {
        match.expert = new mongoose.Types.ObjectId(expertId);
      }

      if (status && status !== "ALL") {
        match.status = status;
      }

      const [items, total] = await Promise.all([
        Payment.find(match)
          .populate("customer", "name email")
          .populate("expert", "name email")
          .populate("service", "title")
          .populate("booking", "code startAt status")
          .sort({ createdAt: -1 })
          .skip(skip)
          .limit(limitNum)
          .lean(),
        Payment.countDocuments(match),
      ]);

      res.json({
        items,
        page: pageNum,
        pageSize: limitNum,
        total,
      });
    } catch (e) {
      console.error("admin earnings payments error:", e);
      res
        .status(500)
        .json({ message: "Failed to load payments list", error: e.message });
    }
  }
);

/* =========================
   💳 Admin Payments List (Refund Screen)
   ========================= */

router.get("/payments",auth(), requireRole("ADMIN"),async (req, res) => {
    try {
      const { status } = req.query;
      const filter = {};
      if (status) filter.status = status;

      const payments = await Payment.find(filter)
        .populate("customer", "name email")
        .populate("expert", "name email")
        .populate("service", "title")
        .populate("booking", "code status startAt")
        .sort({ createdAt: -1 })
        .limit(200); // ممكن تعملي pagination بعدين

      res.json({ items: payments });
    } catch (e) {
      console.error("❌ /admin/payments error:", e);
      res
        .status(500)
        .json({ message: "Failed to load payments", error: e.message });
    }
  }
);

/* =========================
   👀 عرض الخبراء بانتظار الموافقة
   ========================= */
router.get(
  "/experts/pending",
  auth(),
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const pendingProfiles = await ExpertProfile.find({ status: "pending" })
        .populate("userId", "name email profileImageUrl gender role isVerified isApproved")
        .select(
          "userId name specialization profileImageUrl createdAt updatedAt"
        );

      res.json({ pending: pendingProfiles });
    } catch (e) {
      console.error("❌ Failed to load pending experts:", e.message);
      res.status(500).json({
        message: "Failed to load pending experts",
        error: e.message,
      });
    }
  }
);

/* =========================
   ✅ الموافقة على بروفايل خبير
   ========================= */
router.patch(
  "/experts/:profileId/approve",
  auth(),
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const { profileId } = req.params;

      const profile = await ExpertProfile.findById(profileId);
      if (!profile)
        return res.status(404).json({ message: "Profile not found" });

      const user = await User.findById(profile.userId).select(
        "_id name email isApproved"
      );
      if (!user) return res.status(404).json({ message: "User not found" });

      await ExpertProfile.updateMany(
        {
          userId: user._id,
          _id: { $ne: profile._id },
          status: { $in: ["approved", "pending"] },
        },
        { $set: { status: "archived" } }
      );

      profile.status = "approved";
      await profile.save();

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

      user.isApproved = true;
      await user.save();

      await sendExpertStatusEmail(user, true);
      await Notification.create({
        userId: user._id,
        title: "Profile Approved ✅",
        message:
          "Congratulations! Your updated expert profile has been approved by the admin.",
        type: "success",
      });

      res.json({
        message: "Expert profile approved successfully.",
        user,
        profile,
      });
    } catch (e) {
      console.error("❌ Approval error:", e.message);
      res
        .status(500)
        .json({ message: "Approval failed", error: e.message });
    }
  }
);

/* =========================
   ❌ رفض بروفايل خبير
   ========================= */
router.patch(
  "/experts/:profileId/reject",
  auth(),
  requireRole("ADMIN"),
  async (req, res) => {
    try {
      const { profileId } = req.params;
      const { reason } = req.body;

      const profile = await ExpertProfile.findById(profileId);
      if (!profile)
        return res.status(404).json({ message: "Profile not found" });

      const user = await User.findById(profile.userId).select(
        "_id name email isApproved"
      );
      if (!user) return res.status(404).json({ message: "User not found" });

      profile.status = "rejected";
      profile.rejectionReason = reason || "No reason provided.";
      await profile.save();

      const stillApproved = await ExpertProfile.findOne({
        userId: user._id,
        status: "approved",
      });

      if (!stillApproved) {
        user.isApproved = false;
        await user.save();
      }

      res.json({ message: "Expert profile rejected.", user, profile });
    } catch (e) {
      console.error("❌ Reject error:", e.message);
      res.status(500).json({ message: "Reject failed", error: e.message });
    }
  }
);

/* =========================
   👤 عرض بروفايل خبير معيّن (للأدمن)
   ========================= */
router.get("/experts/:id/profile", async (req, res) => {
  try {
    const profile = await ExpertProfile.findById(req.params.id).populate(
      "userId",
      "name email gender age isVerified isApproved"
    );

    if (!profile)
      return res.status(404).json({ message: "Expert profile not found" });

    res.status(200).json({
      user: profile.userId,
      profile,
    });
  } catch (err) {
    console.error("❌ Error fetching expert profile:", err);
    res.status(500).json({ message: "Server error fetching profile" });
  }
});

export default router;
