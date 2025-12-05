import express from "express";
import { reply } from "../controllers/chatbot.controller.js";

const router = express.Router();

// IMPORTANT: this must NOT have any auth middleware
router.post("/", reply);

export default router;
