// src/routes/expertEarnings.route.js
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";
import Payment from "../models/payment.model.js";
import Booking from "../models/booking.model.js";

const router = Router();

/**
 * 🔹 Helper: بناء فلتر التاريخ من query ?from&to
 */
function buildDateFilter(req) {
  const { from, to } = req.query || {};
  const createdAt = {};
  if (from) createdAt.$gte = new Date(from);
  if (to) createdAt.$lte = new Date(to);
  return Object.keys(createdAt).length ? { createdAt } : {};
}

/**
 * GET /api/expert/earnings/summary
 * ملخص أرباح الخبير (مع إمكانية فلترة بالتاريخ)
 */
router.get("/summary", auth(), requireRole("EXPERT"), async (req, res) => {
  try {
    const expertId = req.user.id;
    const dateFilter = buildDateFilter(req);

    // فقط المدفوعات التي تم تحصيلها فعلياً
    const payments = await Payment.find({
      expert: expertId,
      status: "CAPTURED",
      ...dateFilter,
    });

    const totalRevenue = payments.reduce((sum, p) => sum + (p.amount || 0), 0);
    const totalPlatformFees = payments.reduce(
      (sum, p) => sum + (p.platformFee || 0),
      0
    );
    const totalNetToExpert = payments.reduce(
      (sum, p) => sum + (p.netToExpert || 0),
      0
    );

    // عدد الجلسات المكتملة للخبير في نفس الفترة
    const bookingFilter = {
      expert: expertId,
      status: "COMPLETED",
      ...dateFilter,
    };

    const bookingsCount = await Booking.countDocuments(bookingFilter);

    return res.json({
      totalRevenue,
      totalPlatformFees,
      totalNetToExpert,
      bookingsCount,
      paymentsCount: payments.length,
    });
  } catch (e) {
    console.error("expert earnings summary error:", e);
    res.status(500).json({ error: "Failed to load earnings summary" });
  }
});

/**
 * GET /api/expert/earnings/payments
 * لستة المدفوعات الخاصة بالخبير (مع فلترة بالتاريخ)
 */
router.get("/payments", auth(), requireRole("EXPERT"), async (req, res) => {
  try {
    const expertId = req.user.id;
    const dateFilter = buildDateFilter(req);

    const payments = await Payment.find({
      expert: expertId,
      status: { $in: ["AUTHORIZED", "CAPTURED", "REFUND_PENDING", "REFUNDED"] },
      ...dateFilter,
    })
      .populate("service")
      .populate("booking")
      .sort({ createdAt: -1 });

    return res.json({ items: payments });
  } catch (e) {
    console.error("expert earnings payments error:", e);
    res.status(500).json({ error: "Failed to load payments list" });
  }
});

export default router;
