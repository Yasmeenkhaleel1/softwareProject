import express from 'express';
import multer from 'multer';
import bcrypt from 'bcryptjs';
import userModel from '../models/user/user.model.js';

const router = express.Router();
const upload = multer({ dest: "uploads/" });

// POST /api/signup
router.post('/signup', async (req, res) => {
  try {
    const { name, email, password, age, gender, role } = req.body;

    const existingUser = await userModel.findOne({ email });
    if (existingUser) return res.status(400).json({ message: 'Email already exists' });

    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = new userModel({ name, email, password: hashedPassword, age, gender, role });
    await newUser.save();

    res.status(201).json({ message: 'User registered successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: 'Internal server error' });
  }
});

// PUT /api/users/:id
router.put('/:id', upload.single('profilePic'), async (req, res) => {
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
