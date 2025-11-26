// src/routes/payments.routes.js
import { Router } from "express";
import { chargePublic } from "../controllers/payments.controller.js";

const router = Router();

// 💳 Public Payment endpoint — no auth
router.post("/public/payments/charge", chargePublic);

export default router;
