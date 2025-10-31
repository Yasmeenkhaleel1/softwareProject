import express from "express";
import {
  getMyCustomerProfile,
  updateMyCustomerProfile,
  viewCustomerProfile,
  listApprovedExpertsForCustomers, // ✅ أضف هذا
} from "../controllers/customer.controller.js";

import { auth } from "../middleware/auth.js"; // ✅ uses same auth middleware

const router = express.Router();

/**
 * Auth Rules:
 * - CUSTOMER can view or update their own profile.
 * - Public users can view a customer's profile (optional).
 */

// ===== Customer Endpoints =====
router.get("/customers/me", auth("CUSTOMER"), getMyCustomerProfile);
router.patch("/customers/me", auth("CUSTOMER"), updateMyCustomerProfile);

// ===== Public Endpoint (optional) =====
router.get("/customers/view/:userId", viewCustomerProfile);
// ✅ عرض جميع الخبراء الموافق عليهم للعملاء
router.get("/customers/experts", auth("CUSTOMER"), listApprovedExpertsForCustomers);


export default router;