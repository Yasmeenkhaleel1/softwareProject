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

router.get("/customers/me", auth("CUSTOMER"), getMyCustomerProfile);
router.patch("/customers/me", auth("CUSTOMER"), updateMyCustomerProfile);
router.get("/customers/view/:userId", viewCustomerProfile);

// customers: list approved experts
router.get("/customers/experts", auth("CUSTOMER"), listApprovedExpertsForCustomers);

// customers: view expert + their services
router.get("/experts/:id", auth("CUSTOMER"), getExpertPublicProfile);
router.get("/experts/:id/services", auth("CUSTOMER"), listPublishedServicesForExpert);

export default router;