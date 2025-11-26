import { Router } from "express";
import { getCalendarStatus } from "../controllers/calendarStatus.controller.js";

const router = Router();

// ✅ API جديدة لعرض حالة الأيام والساعات
router.get("/public/experts/:expertId/calendar-status", getCalendarStatus);

export default router;
