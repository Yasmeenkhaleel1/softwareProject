// src/routes/chatbot.routes.js
import express from "express";
import { handleChatbotMessage } from "../controllers/chatbot.controller.js";

const router = express.Router();

// POST /api/chatbot
router.post("/chatbot", handleChatbotMessage);

export default router;
