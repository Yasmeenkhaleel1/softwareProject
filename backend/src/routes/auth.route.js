import express from "express";
import * as authController from "../models/authController.js";
import { verifyToken } from "../config/jwt.js";
const router = express.Router();

router.post("/change-password", /* verifyToken, */ authController.changePassword);
router.post('/signup', authController.signup);
router.post('/verify-otp', authController.verifyOTP); 
router.post('/login', authController.login);   
router.post('/verify-otp', authController.verifyOTP);
export default router;
