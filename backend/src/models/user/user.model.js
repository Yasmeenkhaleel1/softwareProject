//src/models/user/user.modle 
import mongoose from "mongoose";

const roles = ["EXPERT", "CUSTOMER", "ADMIN"];

const userSchema = new mongoose.Schema(
  {
    // ✅ المعلومات الأساسية
    name: { type: String, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },
    

   fcmTokens: [
      {
    token: { type: String, index: true },
    platform: { type: String, enum: ["android", "ios", "web"] },
    deviceId: String,
    userAgent: String,
    lastSeenAt: { type: Date, default: Date.now },
     },
   ],



    // ✅ بيانات إضافية
    age: { type: Number, min: 1, max: 120 },
    gender: { type: String, enum: ["MALE", "FEMALE", "OTHER"], default: "OTHER" },
    role: { type: String, enum: roles, default: "CUSTOMER" },

    // ✅ صورة المستخدم (profile picture)
    profilePic: { type: String, default: null },

    // ✅ حالة التفعيل بالبريد (OTP)
    isVerified: { type: Boolean, default: false },
    verificationCode: { type: String },
    codeExpiresAt: { type: Date },

    // ✅ حالة الخبير
    isApproved: { type: Boolean, default: false }, // هل الأدمن وافق عليه
    hasProfile: { type: Boolean, default: false }, // هل الخبير أنشأ ملفه الشخصي
  },
  { timestamps: true }
);

// ⚙️ لجعل البحث السريع ممكن بالإيميل
userSchema.index({ email: 1 });

export default mongoose.model("User", userSchema);
export { roles };
