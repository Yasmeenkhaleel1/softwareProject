// src/routes/bookings.routes.js
import express from "express";
import { createBookingPublic } from "../controllers/bookings.controller.js";

const router = express.Router();

// PUBLIC: POST /api/bookings
router.post("/bookings", createBookingPublic);

export default router;
