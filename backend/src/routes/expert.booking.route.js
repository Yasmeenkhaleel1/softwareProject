// src/routes/expert.booking.route.js
import { Router } from "express";
import { auth } from "../middleware/auth.js";
import { requireRole } from "../middleware/requireRole.js";
import {
listBookings,
getBooking,
createBooking,
acceptBooking,
declineBooking,
rescheduleBooking,
startBooking,
completeBooking,
cancelBooking,
markNoShow,
overviewStats,
} from "../controllers/expertBooking.controller.js";
const router = Router();
router.use(auth());
router.use(requireRole("EXPERT"));
router.get("/expert/bookings", listBookings);
router.get("/expert/bookings/overview", overviewStats);
router.get("/expert/bookings/:id", getBooking);
//للتجربة – في الإنتاج عادة العميل هو الذي ينشئ create مبدئيًا نوفر
router.post("/expert/bookings", createBooking);
router.post("/expert/bookings/:id/accept", acceptBooking);
router.post("/expert/bookings/:id/decline", declineBooking);
router.post("/expert/bookings/:id/reschedule", rescheduleBooking);
router.post("/expert/bookings/:id/start", startBooking);
router.post("/expert/bookings/:id/complete", completeBooking);
router.post("/expert/bookings/:id/cancel", cancelBooking);
router.post("/expert/bookings/:id/no-show", markNoShow);
export default router;
