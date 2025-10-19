import mongoose from "mongoose";

const roles = ["EXPERT", "CUSTOMER", "ADMIN"];

const userSchema = new mongoose.Schema(
  {
    // ✅ المعلومات الأساسية
    name: { type: String, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true },

    // ✅ بيانات إضافية
    age: { type: Number, min: 1, max: 120 },
    gender: { type: String, enum: ["MALE", "FEMALE", "OTHER"], default: "OTHER" },
    role: { type: String, enum: roles, default: "CUSTOMER" },

    // ✅ صورة المستخدم (profile picture)
    profilePic: { type: String, default: null },

    // ✅ حالة التفعيل
    isVerified: { type: Boolean, default: false },

    // ✅ كود التفعيل (OTP)
    verificationCode: { type: String },
    codeExpiresAt: { type: Date },
  },
  { timestamps: true }
);

// ⚙️ لجعل البحث السريع ممكن بالإيميل
userSchema.index({ email: 1 });

export default mongoose.model("User", userSchema);
export { roles };
