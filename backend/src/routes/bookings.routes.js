import express from "express";
import { createBookingPublic } from "../controllers/bookings.controller.js";
import Booking from "../models/booking.model.js";

const router = express.Router();

/* =========================================================
   1) CREATE BOOKING (PUBLIC)
========================================================= */
router.post("/bookings", createBookingPublic);

/* =========================================================
   2) GET BOOKINGS (PUBLIC) — customer must pass ?customer=ID
========================================================= */
router.get("/bookings", async (req, res) => {
  try {
    const customer = req.query.customer;
    if (!customer) {
      return res
        .status(400)
        .json({ message: "customer query param is required" });
    }

    const bookings = await Booking.find({ customer })
      .populate("expert", "name specialization profileImageUrl")
      .populate("service", "title durationMinutes price")
      .sort({ startAt: -1 });

    return res.json({ bookings });
  } catch (err) {
    console.error("Error loading bookings:", err);
    return res.status(500).json({
      message: "Failed to load bookings",
      error: err.message,
    });
  }
});

/* =========================================================
   3) START SESSION (PUBLIC)
========================================================= */
router.post("/bookings/:id/start-session", async (req, res) => {
  try {
    const booking = await Booking.findById(req.params.id);
    if (!booking)
      return res.status(404).json({ message: "Booking not found" });

    // Already has meeting link? → return same
    if (booking.meetingUrl) {
      return res.json({ meetingUrl: booking.meetingUrl });
    }

    // Create new Jitsi room
    const roomId = `session_${booking._id}_${Date.now()}`;
    const meetingUrl = `https://meet.jit.si/${roomId}`;

    booking.meetingUrl = meetingUrl;
    booking.status = "IN_PROGRESS";
    await booking.save();

    return res.json({ meetingUrl });
  } catch (err) {
    console.error("Start session error:", err);
    return res.status(500).json({
      message: "Error creating session",
      error: err.message,
    });
  }
});

/* =========================================================
   4) RATE SESSION (PUBLIC)
========================================================= */
router.post("/bookings/:id/rate", async (req, res) => {
  try {
    const { rating } = req.body;
    if (!rating || rating < 1 || rating > 5) {
      return res
        .status(400)
        .json({ message: "Rating must be between 1 and 5" });
    }

    const booking = await Booking.findById(req.params.id);
    if (!booking)
      return res.status(404).json({ message: "Booking not found" });

    booking.status = "COMPLETED";
    booking.customerRating = rating;
    await booking.save();

    return res.json({ message: "Rating submitted successfully" });
  } catch (err) {
    console.error("Rate session error:", err);
    return res.status(500).json({
      message: "Error rating session",
      error: err.message,
    });
  }
});

export default router;
