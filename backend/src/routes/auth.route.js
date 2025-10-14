import express from "express";
import { login, changePassword } from "../models/authController.js";
import { verifyToken } from "../config/jwt.js";

const router = express.Router();

router.post("/login", login);
router.post("/change-password", verifyToken, changePassword);

export default router;
