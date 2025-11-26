import express from "express";
import { auth } from "../middleware/auth.js";
import { getMyAvailability, updateMyAvailability } from "../controllers/availability.controller.js";

const router = express.Router();

/* ===========================================================
   🧑‍💼 Expert Availability Management
   =========================================================== */
router.get("/expert/availability/me", auth("EXPERT"), getMyAvailability);
router.put("/expert/availability/me", auth("EXPERT"), updateMyAvailability);

export default router;
