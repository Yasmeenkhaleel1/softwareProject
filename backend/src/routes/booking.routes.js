// src/routes/booking.routes.js
import express from "express";
import {
  createBookingPublic,
  getCustomerBookings,
  addCustomerReview,
  cancelCustomerBooking,
} from "../controllers/booking.controller.js";
import { auth } from "../middleware/auth.js";

const bookingRouter = express.Router();

/* ===========================================================
   🟢 Public Routes (Customer side)
   =========================================================== */

// ✅ إنشاء حجز جديد من قبل العميل
// POST /api/public/bookings
bookingRouter.post("/public/bookings", createBookingPublic);

// ✅ جلب كل حجوزات العميل (للواجهة MyBookings)
bookingRouter.get("/public/bookings", getCustomerBookings);

// ✅ تقييم حجز من قبل العميل (يتطلب تسجيل الدخول)
bookingRouter.post(
  "/customer/bookings/:id/review",
  auth(),
  addCustomerReview
);

// ✅ إلغاء حجز من قبل العميل (فقط لو PENDING)
bookingRouter.post(
  "/customer/bookings/:id/cancel",
  auth(),
  cancelCustomerBooking
);
export default bookingRouter;
