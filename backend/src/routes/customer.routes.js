// src/routes/customer.routes.js
import express from "express";
import { auth } from "../middleware/auth.js";
import {
  getMyCustomerProfile,
  updateMyCustomerProfile,
  viewCustomerProfile,
  listApprovedExpertsForCustomers,
  getExpertPublicProfile,
  listPublishedServicesForExpert,
} from "../controllers/customer.controller.js";

const router = express.Router();

/* ===========================================================
   🧑‍💼 Customer Personal Profile
   =========================================================== */
router.get("/customers/me", auth("CUSTOMER"), getMyCustomerProfile);
router.patch("/customers/me", auth("CUSTOMER"), updateMyCustomerProfile);

/* ===========================================================
   🧍 Public Customer View
   =========================================================== */
router.get("/customers/view/:userId", viewCustomerProfile);

/* ===========================================================
   🧠 Explore Experts (Customer side)
   =========================================================== */
// ✅ قائمة الخبراء المعتمدين (مع دعم الصفحة pagination)
router.get("/public/experts", listApprovedExpertsForCustomers);

// ✅ عرض بروفايل خبير واحد (ExpertProfile._id)
router.get("/public/experts/:id", getExpertPublicProfile);

// ✅ عرض الخدمات المنشورة لذلك الخبير
router.get("/public/experts/:id/services", listPublishedServicesForExpert);

export default router;
