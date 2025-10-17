import bcrypt from "bcryptjs";
import userModel from "../models/user/user.model.js";
import { generateToken } from "../config/jwt.js";
import { sendEmail } from "../services/sendEmail.js";

export const signup = async (req, res) => {
  try {
    const { name, email, password, age, gender, role } = req.body;

    const existingUser = await userModel.findOne({ email });
    if (existingUser)
      return res.status(409).json({ message: "User already exists" });

    const hashedPassword = await bcrypt.hash(password, 10);

    const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
    const otpExpiry = new Date(Date.now() + 10 * 60 * 1000);

    const newUser = new userModel({
      name,
      email,
      password: hashedPassword,
      age,
      gender,
      role,
      otp: { code: otpCode, expires: otpExpiry },
      isVerified: false,
    });

    await newUser.save();

    try {
      await sendEmail(email, otpCode); 
      console.log("✅ Verification email sent successfully");
      
      res.status(200).json({
        message: "User registered successfully. Check your email for the verification code.",
        userId: newUser._id,
      });
      
    } catch (emailError) {
      console.error("❌ Email sending failed:", emailError);
      
      
      res.status(200).json({
        message: "User registered, but verification email failed to send. Please contact support.",
        userId: newUser._id,
      });
    }

  } catch (err) {
    console.error("❌ Error during signup:", err.message);
    res.status(500).json({
      message: "Registration failed",
      error: err.message,
    });
  }
};
export const verifyOTP = async (req, res) => {
  try {
    const { email, otpCode } = req.body;

    const user = await userModel.findOne({ email });
    if (!user) return res.status(404).json({ message: "User not found" });

    if (
      !user.otp ||
      user.otp.code !== otpCode ||
      user.otp.expires < new Date()
    ) {
      return res
        .status(400)
        .json({ message: "Invalid or expired verification code" });
    }


    user.isVerified = true;
    user.otp = undefined;
    await user.save();

    const token = generateToken(user);
    res.status(200).json({
      message: "Email verified successfully. Login granted.",
      token,
      user: { id: user._id, name: user.name, role: user.role },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};


export const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await userModel.findOne({ email });
    if (!user) return res.status(404).json({ message: "User not found" });

  
   
 
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) return res.status(401).json({ message: "Invalid credentials" });

    const token = generateToken(user);

    res.status(200).json({
      message: "Login successful",
      token,
      user: { id: user._id, name: user.name, role: user.role },
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};

// --------------------------------------------------
// -------- CHANGE PASSWORD (تغيير كلمة المرور) --------
// --------------------------------------------------
export const changePassword = async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body;
    const user = await userModel.findById(req.user.id);

    if (!user) return res.status(404).json({ message: "User not found" });

    // Verify old password
    const isMatch = await bcrypt.compare(oldPassword, user.password);
    if (!isMatch)
      return res.status(400).json({ message: "Old password is incorrect" });

    // Save new password
    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    res.json({ message: "Password changed successfully" });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
};
