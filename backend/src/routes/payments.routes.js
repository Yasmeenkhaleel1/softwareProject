// src/routes/payments.routes.js
import { Router } from "express";
import { chargePublic } from "../controllers/payments.controller.js";

const router = Router();

// Public endpoint — no auth middleware
router.post("/payments/charge", chargePublic);

export default router;
