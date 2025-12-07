import { Router } from "express";
import { auth } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";
import {
  createDispute,
  listDisputes,
  decideDispute,
} from "../controllers/dispute.controller.js";

const router = Router();

// 🎯 الكستمر يفتح Dispute
router.post("/public/disputes", auth(), requireRole("CUSTOMER"), createDispute);

// 🎯 الأدمن يشوف / يحسم
router.get("/admin/disputes", auth(), requireRole("ADMIN"), listDisputes);
router.patch("/admin/disputes/:id/decision", auth(), requireRole("ADMIN"), decideDispute);

export default router;
