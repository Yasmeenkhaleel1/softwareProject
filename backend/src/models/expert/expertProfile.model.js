// src/models/expert/expertProfile.model.js
import mongoose from "mongoose";

/**
 * ExpertProfile:
 * - مرتبط بمستخدم عبر userId
 * - يحتوي حقول أساسية للبروفايل
 * - status: pending | approved | rejected (افتراضي pending)
 * - timestamps: createdAt/updatedAt تلقائياً
 */
const expertProfileSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
      index: true, // لتحسين الاستعلامات بالـ userId
    },
    name: { type: String, required: true, trim: true },
    bio: { type: String, required: true, trim: true },
    specialization: { type: String, required: true, trim: true },
    experience: { type: Number, required: true, min: 0 },
    location: { type: String, required: true, trim: true },
    
     profileImageUrl: { type: String },
    // Arrays of strings (URLs)
    certificates: [{ type: String, trim: true }],
    gallery: [{ type: String, trim: true }],

    // approval workflow
    status: {
      type: String,
      enum: ["pending", "approved", "rejected"],
      default: "pending",
      index: true,
    },



    // ممكن نخزن سبب الرفض من الأدمن
    rejectionReason: { type: String, trim: true },
  },
  { timestamps: true }
);

export default mongoose.model("ExpertProfile", expertProfileSchema);
