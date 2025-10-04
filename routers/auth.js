const express = require('express');
const router = express.Router();
const User = require('../models/User');
const bcrypt = require('bcryptjs');

// Register
router.post('/signup', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // Check if user exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create new user
    const user = new User({ name, email, password: hashedPassword });
    await user.save();

    res.json({ message: 'User registered successfully', user });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
