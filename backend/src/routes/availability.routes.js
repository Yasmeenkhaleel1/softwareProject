// src/routes/availability.routes.js
import express from "express";
import { getAvailableSlots } from "../controllers/availability.controller.js";

const router = express.Router();

router.get("/experts/:expertId/availability/slots", getAvailableSlots);

export default router;
