import bcrypt from "bcryptjs";
import userModel from "../models/user/user.model.js";
import { generateToken } from "../config/jwt.js";
import postmark from "postmark"; 
import dotenv from 'dotenv'; 
dotenv.config({ path: './src/.env' }); 

// 🔑 إعداد عميل Postmark باستخدام Server API Token من ملف .env
const client = new postmark.ServerClient(process.env.POSTMARK_API_TOKEN);


// ----------------------------------------------------------------
// ----------- SIGNUP (مع إرسال رمز التحقق عبر Postmark) -----------
// ----------------------------------------------------------------
export const signup = async (req, res) => {
    try {
        const { name, email, password, age, gender, role } = req.body;

        const existingUser = await userModel.findOne({ email });
        if (existingUser) {
            return res.status(409).json({ message: "User with this email already exists" });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        
        // 1. توليد رمز التحقق (OTP)
        const otpCode = Math.floor(100000 + Math.random() * 900000).toString();
        const otpExpiry = new Date(Date.now() + 10 * 60 * 1000); // صالح لمدة 10 دقائق

        // 2. إنشاء المستخدم وحفظ الـ OTP في قاعدة البيانات
        const newUser = new userModel({
            name, email, password: hashedPassword, age, gender, role,
            otp: { code: otpCode, expires: otpExpiry },
            isVerified: false,
        });

        await newUser.save();

        // 3. إعداد وإرسال رمز التحقق عبر Postmark
        const msg = {
            From: process.env.SENDER_SIGNATURE_EMAIL, // 🔑 البريد المؤكد في Postmark (من ملف .env)
            To: email, // المستلم هو بريد المستخدم
            Subject: 'Lost Treasures - Email Verification Code',
            HtmlBody: `<p>Your 6-digit verification code is: <b style="font-size: 20px;">${otpCode}</b></p>`,
        };

        const response = await client.sendEmail(msg); // 🔑 محاولة الإرسال

        console.log("POSTMARK: Email attempt sent successfully. Message ID:", response.MessageID);

        // إذا نجح الإرسال
        res.status(200).json({ 
            message: "User registered successfully, please check your email for verification code",
            userId: newUser._id
        });

    } catch (err) {
        // 🚨 طباعة خطأ Postmark الواضح
        console.error("POSTMARK ERROR:", err.message);
        
        // إرجاع رسالة تشير إلى نجاح التسجيل في DB لكن فشل الإرسال
        res.status(500).json({ 
            message: "Registration successful, but failed to send verification email. Please check server logs.",
            userId: newUser._id
        });
    }
};

// ------------------------------------------------
// ----------- VERIFY OTP (تأكيد الرمز) -----------
// ------------------------------------------------
export const verifyOTP = async (req, res) => {
    try {
        const { email, otpCode } = req.body;

        const user = await userModel.findOne({ email });
        if (!user) return res.status(404).json({ message: "User not found" });

        // 1. التحقق من الرمز وانتهاء الصلاحية
        // تحقق أولاً مما إذا كان حقل OTP موجودًا قبل الوصول إلى خصائصه
        if (!user.otp || user.otp.code !== otpCode || user.otp.expires < new Date()) {
            return res.status(400).json({ message: "Invalid or expired verification code" });
        }

        // 2. تحديث حالة التحقق وحذف الرمز
        user.isVerified = true;
        user.otp = undefined; // حذف الرمز بعد التحقق الناجح
        await user.save();

        // 3. تسجيل الدخول تلقائيًا بعد التحقق
        const token = generateToken(user);
        res.status(200).json({ 
            message: "Email verified successfully. Login granted.",
            token,
            user: { id: user._id, name: user.name, role: user.role }
        });

    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};

// ------------------------------------
// ----------- LOGIN (دخول) -----------
// ------------------------------------
export const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        const user = await userModel.findOne({ email });
        if (!user) return res.status(404).json({ message: "User not found" });

        // 🔑 منع الدخول إذا لم يتم التحقق
        if (!user.isVerified) {
             return res.status(403).json({ message: "Account not verified. Please verify your email." });
        }
        
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
// ----------- CHANGE PASSWORD (تغيير كلمة المرور) -----------
// --------------------------------------------------
export const changePassword = async (req, res) => {
    try {
        const { oldPassword, newPassword } = req.body;
        // هنا يجب أن تعتمد على الـ token لتحديد المستخدم
        const user = await userModel.findById(req.user.id); 
        if (!user) return res.status(404).json({ message: "User not found" });

        const isMatch = await bcrypt.compare(oldPassword, user.password);
        if (!isMatch) return res.status(400).json({ message: "Old password is incorrect" });

        user.password = await bcrypt.hash(newPassword, 10);
        await user.save();

        res.json({ message: "Password changed successfully" });
    } catch (err) {
        res.status(500).json({ message: err.message });
    }
};