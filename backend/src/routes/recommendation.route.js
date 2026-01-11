import express from "express";
import { getSmartRecommendations } from "../controllers/recommendation.controller.js";

const router = express.Router();

// 🔮 Smart AI Recommendations
router.get("/smart",  getSmartRecommendations);

export default router;
