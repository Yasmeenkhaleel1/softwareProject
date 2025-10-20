import express from "express";
import multer from "multer";
import userModel from "../models/user/user.model.js";
import { auth } from "../middleware/auth.js"; // ✅ تأكد أن المسار صحيح

const router = express.Router();
const upload = multer({ dest: "uploads/" });

/**
 * ✅ GET /api/me
 * يرجع بيانات المستخدم الحالي بناءً على التوكن فقط
 */
router.get("/me", auth(), async (req, res) => {
  try {
    const user = await userModel.findById(req.user.id).select("-passwordHash");
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // ✅ إرجاع معلومات إضافية لدعم منطق الواجهة
    res.json({
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        age: user.age,
        gender: user.gender,
        role: user.role,
        profilePic: user.profilePic,
        isVerified: user.isVerified,
        isApproved: user.isApproved, // ✅ تمت إضافتها
        hasProfile: user.hasProfile, // ✅ تمت إضافتها
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
      },
    });
  } catch (error) {
    res
      .status(500)
      .json({ message: "Error fetching user", error: error.message });
  }
});

/**
 * ✅ PUT /api/me
 * تحديث بيانات المستخدم الحالي بناءً على التوكن فقط
 */
router.put("/me", auth(), async (req, res) => {
  try {
    const { name, age, gender, profilePic } = req.body;

    const updates = {};
    if (name) updates.name = name;
    if (age) updates.age = age;
    if (gender) updates.gender = gender;
    if (profilePic) updates.profilePic = profilePic;

    const updatedUser = await userModel
      .findByIdAndUpdate(req.user.id, updates, { new: true })
      .select("-passwordHash");

    if (!updatedUser)
      return res.status(404).json({ message: "User not found" });

    res.json({
      message: "Profile updated successfully",
      user: updatedUser,
    });
  } catch (error) {
    console.error("❌ Error updating profile:", error);
    res
      .status(500)
      .json({ message: "Error updating profile", error: error.message });
  }
});

/**
 * ✅ (اختياري) إنشاء مستخدم جديد
 */
router.post("/signup", async (req, res) => {
  try {
    const { name, email, password, age, gender, role } = req.body;

    const existingUser = await userModel.findOne({ email });
    if (existingUser)
      return res.status(400).json({ message: "Email already exists" });

    const newUser = new userModel({
      name,
      email,
      password,
      age,
      gender,
      role,
    });
    await newUser.save();

    res.status(201).json({ message: "User registered successfully" });
  } catch (err) {
    res
      .status(500)
      .json({ message: "Internal server error", error: err.message });
  }
});

export default router;
