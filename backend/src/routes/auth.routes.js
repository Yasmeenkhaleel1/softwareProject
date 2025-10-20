import { Router } from "express";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { body, validationResult } from "express-validator";
import nodemailer from "nodemailer";
import dotenv from "dotenv";
dotenv.config();
import User, { roles } from "../models/user/user.model.js";

const router = Router();

// === mailer setup ===
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST,
  port: Number(process.env.SMTP_PORT),
  secure: process.env.SMTP_SECURE === "true",
  auth: { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS },
});

// ✅ توليد رمز OTP عشوائي مكون من 6 أرقام
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

// === إرسال كود التفعيل ===
const sendVerificationEmail = async (user, code) => {
  const html = `
    <div style="font-family: Arial; line-height: 1.6">
      <h2>Verify your email</h2>
      <p>Use the code below to verify your account:</p>
      <h1 style="color:#1a73e8; letter-spacing:4px;">${code}</h1>
      <p>This code will expire in 10 minutes.</p>
    </div>
  `;

  await transporter.sendMail({
    from: process.env.SMTP_FROM,
    to: user.email,
    subject: "Your verification code — Lost Treasures",
    html,
  });
};

// === POST /auth/register ===
router.post(
  "/register",
  [
    body("email").isEmail(),
    body("password").isLength({ min: 6 }),
    body("age").optional().isInt({ min: 1, max: 120 }),
    body("gender").optional().isIn(["MALE", "FEMALE", "OTHER"]),
    body("role").optional().isIn(roles),
  ],
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty())
      return res.status(400).json({ errors: errors.array() });

    const { email, password, age, gender, role } = req.body;
    const exists = await User.findOne({ email });
    if (exists) return res.status(409).json({ message: "Email already registered" });

    const passwordHash = await bcrypt.hash(password, 10);
    const otpCode = generateOTP();

    const user = await User.create({
      email,
      passwordHash,
      age,
      gender,
      role,
      isVerified: false,
      verificationCode: otpCode,
      codeExpiresAt: new Date(Date.now() + 10 * 60 * 1000),
    });

    try {
      await sendVerificationEmail(user, otpCode);
      console.log("✅ Verification code sent to:", user.email);
    } catch (e) {
      console.error("❌ Email sending failed:", e.message);
    }

    return res.status(201).json({ message: "Registered. Check your email for the code." });
  }
);

// === POST /auth/verify-code ===
router.post("/verify-code", async (req, res) => {
  const { email, code } = req.body;

  const user = await User.findOne({ email });
  if (!user) return res.status(404).json({ message: "User not found" });

  if (user.isVerified)
    return res.status(400).json({ message: "Already verified" });

  if (user.verificationCode !== code)
    return res.status(400).json({ message: "Invalid code" });

  if (new Date() > new Date(user.codeExpiresAt))
    return res.status(400).json({ message: "Code expired" });

  user.isVerified = true;
  user.verificationCode = null;
  user.codeExpiresAt = null;
  await user.save();

  res.json({ message: "Account verified successfully!" });
});

// === POST /auth/resend-code ===
router.post("/resend-code", async (req, res) => {
  const { email } = req.body;
  const user = await User.findOne({ email });
  if (!user) return res.status(404).json({ message: "User not found" });

  if (user.isVerified)
    return res.status(400).json({ message: "Already verified" });

  const newCode = generateOTP();
  user.verificationCode = newCode;
  user.codeExpiresAt = new Date(Date.now() + 10 * 60 * 1000);
  await user.save();

  await sendVerificationEmail(user, newCode);
  res.json({ message: "New code sent to your email." });
});

// === POST /auth/login ===
router.post("/login", async (req, res) => {
  const { email, password } = req.body;
  const user = await User.findOne({ email });
  if (!user) return res.status(401).json({ message: "Invalid credentials" });

  const ok = await bcrypt.compare(password, user.passwordHash);
  if (!ok) return res.status(401).json({ message: "Invalid credentials" });

  if (!user.isVerified) {
    return res.status(403).json({ message: "Email not verified" });
  }

  const token = jwt.sign(
    { id: user._id.toString(), email: user.email, role: user.role },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES || "7d" }
  );

  // ✅ تعديل الإرجاع ليشمل القيم الجديدة
  res.json({
    token,
    user: {
      id: user._id,
      email: user.email,
      role: user.role,
      gender: user.gender,
      age: user.age,
      isVerified: user.isVerified,
      isApproved: user.isApproved, // ✅ تمت إضافتها
      hasProfile: user.hasProfile, // ✅ تمت إضافتها
    },
  });
});

export default router;
