import { Router } from "express";
import bcrypt from "bcryptjs";
import userModel from "../models/user/user.model.js";

const router = Router();

router.post("/signUp", async (req, res) => {
  try {
    const { email, password, name, age, gender } = req.body;

    const passwordHashed = await bcrypt.hash(password, 8);
    const newUser = await userModel.create({
      name,
      email,
      password: passwordHashed,
      age,
      gender,
    });

    return res.status(201).json({ message: "success", user: newUser });
  } catch (error) {
    console.error(" Error in signUp:", error);
    return res.status(500).json({ message: "catch error", error: error.message });
  }
});
router.post("/login", async (req, res) => {
  try {
    const { name, password } = req.body;


    const user = await userModel.findOne({ name });
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // compare password
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid password" });
    }

    // success
    res.status(200).json({
      message: "Login successful",
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        gender: user.gender,
        age: user.age,
      },
    });
  } catch (error) {
    console.error("Login error:", error);
    res.status(500).json({ message: "catch error", error: error.message });
  }
});

export default router;
