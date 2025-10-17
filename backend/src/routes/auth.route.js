import express from "express";
import * as authController from "../controllers/authController.js";
import { verifyToken } from "../config/jwt.js";

console.log("authController:", authController); // 🔍 لمراقبة القيم

const router = express.Router();

router.post('/signup', authController.signup);
router.post('/verify-otp', authController.verifyOTP);
router.post('/login', authController.login);
router.post('/change-password', verifyToken, authController.changePassword);

export default router;
