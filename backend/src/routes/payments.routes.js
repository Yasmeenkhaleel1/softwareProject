// src/routes/payments.routes.js
import { Router } from "express";
import {
  createIntent,
  confirmIntent,
  refundPayment,
  capturePayment,
  cancelPayment,
  
} from "../controllers/payments.stripe.js";
import {
  createConnectAccountLink,
  getConnectStatus,
} from "../controllers/stripeConnect.controller.js";
import { auth } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";

const router = Router();

// 💳 العميل ينشئ Payment Intent
router.post("/intent", auth(), requireRole("CUSTOMER"), createIntent);


router.post("/confirm", auth(), requireRole("CUSTOMER"), confirmIntent);

// ✅ بعد قبول الحجز → Capture
router.post("/capture", auth(), capturePayment);

// ❌ لو الحجز اتلغى قبل الدفع
router.post("/cancel", auth(), cancelPayment);

// 💸 Refund (أدمن فقط)
router.post("/refund", auth(), requireRole("ADMIN"), refundPayment);

// 🧩 Stripe Connect Onboarding للخبير
router.post("/connect/link", auth(), requireRole("EXPERT"), createConnectAccountLink);
router.get("/connect/status", auth(), requireRole("EXPERT"), getConnectStatus);

export default router;
