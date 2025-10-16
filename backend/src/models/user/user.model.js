// src/models/user/user.model.js

import mongoose from "mongoose";

const userSchema = new mongoose.Schema({
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    age: { type: Number },
    gender: { type: String, enum: ['male', 'female', 'other'] },
    role: { type: String, enum: ['customer', 'specialist', 'admin'], default: 'customer' },
    
    // 🔑 حقول التحقق الجديدة
    isVerified: {
        type: Boolean,
        default: false,
    },
    otp: {
        code: String,
        expires: Date,
    },
}, { timestamps: true });

const userModel = mongoose.model('User', userSchema);
export default userModel;