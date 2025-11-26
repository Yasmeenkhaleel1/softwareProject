// src/routes/booking.routes.js
import express from "express";
import {
  createBookingPublic,
  getCustomerBookings,
} from "../controllers/booking.controller.js";

const bookingRouter = express.Router();

/* ===========================================================
   🟢 Public Routes (Customer side)
   =========================================================== */

// ✅ إنشاء حجز جديد من قبل العميل
// POST /api/public/bookings
bookingRouter.post("/public/bookings", createBookingPublic);

// ✅ جلب كل حجوزات العميل (للواجهة MyBookings)
bookingRouter.get("/public/bookings", getCustomerBookings);

export default bookingRouter;
