import express from "express";
import multer from "multer";
import userModel from "../models/user/user.model.js";

const router = express.Router();
const upload = multer({ dest: "uploads/" });

router.put("/:id", upload.single("profilePic"), async (req, res) => {
  try {
    const { name, email } = req.body;
    const updateData = { name, email };
    if (req.file) updateData.profilePic = req.file.path;

    const updatedUser = await userModel.findByIdAndUpdate(req.params.id, updateData, { new: true });
    res.json({ message: "User updated successfully", user: updatedUser });
  } catch (error) {
    res.status(500).json({ message: "Error updating user", error });
  }
});

export default router;
